# frozen_string_literal: true

require 'puppet'
require 'puppet/provider'
require 'json'

# Base provider for storcli-managed resources.
#
# Provides shared helpers for executing storcli/perccli commands, parsing JSON
# output, and converting between Puppet property values and storcli wire values.
#
# Supports `'all'` at multiple levels of the storcli path hierarchy:
#   controller => 'all'   — discovers IDs via `/call show J nolog`
#   virtual_disk => 'all' — discovers VD IDs per controller from the VD LIST
#
# Each provider calls `controller_ids` (and optionally `vd_ids_for`) to resolve
# which targets to manage.  Getters check all targets and report in-sync only
# when every target agrees.  Setters loop through all targets.
class Puppet::Provider::Storcli < Puppet::Provider
  # ---------------------------------------------------------------------------
  # Target discovery
  # ---------------------------------------------------------------------------

  # Return the list of integer controller IDs this resource should manage.
  # When `controller` is 'all', discover IDs from `/call show J nolog`.
  def controller_ids
    return @controller_ids if @controller_ids

    ctrl = @resource[:controller]
    @controller_ids = if ctrl.to_s == 'all'
                        discover_controller_ids
                      else
                        [ctrl.to_i]
                      end
  end

  # Return the list of integer VD IDs for a given controller.
  # When the resource's `virtual_disk` is 'all', discover IDs from the VD LIST.
  # Only meaningful for VD-level resources (others don't define :virtual_disk).
  def vd_ids_for(cid)
    vd = @resource[:virtual_disk] if @resource.class.validparameter?(:virtual_disk)
    return [vd.to_i] if vd && vd.to_s != 'all'

    discover_vd_ids(cid)
  end

  # Yields [controller_id, vd_id] for every VD target this resource manages.
  # Handles all combinations of controller='all' and virtual_disk='all'.
  def each_vd_target
    controller_ids.each do |cid|
      vd_ids_for(cid).each do |vid|
        yield cid, vid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # JSON execution helpers
  # ---------------------------------------------------------------------------

  # Run `storcli_cmd args` and return the parsed JSON hash, or nil on failure.
  def storcli_json(args)
    cmd = @resource[:storcli_cmd]
    raw = Puppet::Util::Execution.execute("#{cmd} #{args}", failonfail: false)
    return nil if raw.nil? || raw.empty?

    JSON.parse(raw)
  rescue JSON::ParserError => e
    Puppet.debug("storcli: JSON parse error from `#{cmd} #{args}`: #{e.message}")
    nil
  end

  # Yields each controller hash from a storcli JSON response.
  # Skips entries whose Command Status is 'Failure'.
  def each_controller(json)
    return unless json.is_a?(Hash)

    json.fetch('Controllers', []).each do |ctrl|
      next if ctrl.dig('Command Status', 'Status') == 'Failure'

      yield ctrl
    end
  end

  # Run `show <setting> J nolog` for a single controller and return the
  # Controller Properties array (array of {"Ctrl_Prop" => ..., "Value" => ...}).
  def show_property_for(cid, setting)
    json = storcli_json("/c#{cid} show #{setting} J nolog")
    return [] unless json

    props = []
    each_controller(json) do |ctrl|
      props.concat(ctrl.dig('Response Data', 'Controller Properties') || [])
    end
    props
  end

  # Lookup a specific Ctrl_Prop value from a properties array.
  def lookup_value(props, ctrl_prop_name)
    entry = props.find { |p| p['Ctrl_Prop'] == ctrl_prop_name }
    entry&.fetch('Value', nil)
  end

  # ---------------------------------------------------------------------------
  # Set helpers (loop through all targets)
  # ---------------------------------------------------------------------------

  # Run a storcli `set` command against a single controller.
  def storcli_set_for(cid, args)
    cmd = @resource[:storcli_cmd]
    output = Puppet::Util::Execution.execute(
      "#{cmd} /c#{cid} #{args} nolog",
      failonfail: true,
    )
    Puppet.debug("storcli set: #{cmd} /c#{cid} #{args} => #{output}")
  end

  # Run a storcli `set` command against every managed controller.
  def storcli_set(args)
    controller_ids.each { |cid| storcli_set_for(cid, args) }
  end

  # Run a storcli `set` command against a single VD target.
  def storcli_vd_set_for(cid, vid, args)
    cmd = @resource[:storcli_cmd]
    output = Puppet::Util::Execution.execute(
      "#{cmd} /c#{cid}/v#{vid} #{args} nolog",
      failonfail: true,
    )
    Puppet.debug("storcli set: #{cmd} /c#{cid}/v#{vid} #{args} => #{output}")
  end

  # Run a storcli `set` command against every managed VD target.
  def storcli_vd_set(args)
    each_vd_target { |cid, vid| storcli_vd_set_for(cid, vid, args) }
  end

  # ---------------------------------------------------------------------------
  # Read helpers (check all targets, return common value)
  # ---------------------------------------------------------------------------

  # Read a controller-level property from every managed controller.
  # Calls the supplied block with (controller_id, properties_array) and
  # expects a normalised value back.
  #
  # Returns the common value if all controllers agree.  If they disagree,
  # returns the first non-nil value (which won't match the desired state,
  # triggering a set on all controllers).  Returns nil when no controllers
  # are found.
  def read_property(setting, &block)
    values = controller_ids.map do |cid|
      props = show_property_for(cid, setting)
      block.call(cid, props)
    end.compact

    return nil if values.empty?

    values.uniq.size == 1 ? values.first : values.first
  end

  # Read a VD-level property from every managed VD target.
  # Calls the supplied block with (controller_id, vd_id, vd_properties_hash)
  # and expects a normalised value back.
  def read_vd_property
    values = []
    each_vd_target do |cid, vid|
      json = storcli_json("/c#{cid}/v#{vid} show all J nolog")
      vd_props = {}
      vd_info = []
      if json
        each_controller(json) do |ctrl|
          data = ctrl.fetch('Response Data', {})
          vd_props = data["VD#{vid} Properties"] || {}
          vd_info = data["/c#{cid}/v#{vid}"] || []
        end
      end
      values << yield(cid, vid, vd_props, vd_info)
    end

    values.compact!
    return nil if values.empty?

    values.uniq.size == 1 ? values.first : values.first
  end

  # ---------------------------------------------------------------------------
  # Value conversion helpers
  # ---------------------------------------------------------------------------

  def bool_to_onoff(val)
    (val == :true || val == true) ? 'on' : 'off'
  end

  def onoff_to_bool(val)
    val.to_s.casecmp('on').zero? ? :true : :false
  end

  def enabled_to_bool(val)
    val.to_s.casecmp('enabled').zero? ? :true : :false
  end

  private

  # Discover controller IDs by running `/call show J nolog`.
  def discover_controller_ids
    json = storcli_json('/call show J nolog')
    return [] unless json

    ids = []
    each_controller(json) do |ctrl|
      id = ctrl.dig('Command Status', 'Controller')
      ids << id.to_i if id
    end
    ids.sort
  end

  # Discover VD IDs for a given controller from its VD LIST.
  def discover_vd_ids(cid)
    json = storcli_json("/c#{cid} show J nolog")
    return [] unless json

    vd_ids = []
    each_controller(json) do |ctrl|
      vd_list = ctrl.dig('Response Data', 'VD LIST') || []
      vd_list.each do |item|
        if item.key?('DG/VD')
          _dg, vid = item['DG/VD'].split('/')
          vd_ids << vid.to_i if vid
        elsif item.key?('VD')
          vd_ids << item['VD'].to_i
        end
      end
    end
    vd_ids.sort
  end
end
