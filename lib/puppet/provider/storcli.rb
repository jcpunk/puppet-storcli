# frozen_string_literal: true

require 'puppet'
require 'puppet/provider'
require 'json'

# Base provider for storcli-managed resources.
#
# Provides shared helpers for executing storcli/perccli commands, parsing JSON
# output, and converting between Puppet property values and storcli wire values.
#
# Supports `controller => 'all'`: the provider discovers every controller via
# `/call show J nolog` and transparently loops when reading or writing settings.
class Puppet::Provider::Storcli < Puppet::Provider
  # Return the list of integer controller IDs this resource should manage.
  # When `controller` is 'all', we discover IDs from `/call show J nolog`.
  # Results are cached for the lifetime of the provider instance.
  def controller_ids
    return @controller_ids if @controller_ids

    ctrl = @resource[:controller]
    if ctrl.to_s == 'all'
      @controller_ids = discover_controller_ids
    else
      @controller_ids = [ctrl.to_i]
    end
  end

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
  # Returns an empty array if the command fails.
  def show_property_for(cid, setting)
    json = storcli_json("/c#{cid} show #{setting} J nolog")
    return [] unless json

    props = []
    each_controller(json) do |ctrl|
      props.concat(ctrl.dig('Response Data', 'Controller Properties') || [])
    end
    props
  end

  # Convenience: show_property for every managed controller.
  # Returns a hash { controller_id => [properties_array] }.
  def show_property_all(setting)
    result = {}
    controller_ids.each do |cid|
      result[cid] = show_property_for(cid, setting)
    end
    result
  end

  # Lookup a specific Ctrl_Prop value from a properties array.
  # Returns the raw "Value" string or nil.
  def lookup_value(props, ctrl_prop_name)
    entry = props.find { |p| p['Ctrl_Prop'] == ctrl_prop_name }
    entry&.fetch('Value', nil)
  end

  # Run a storcli `set` command against a single controller.
  # Raises on failure so Puppet reports the error.
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

  # Read a property from every managed controller.  Calls the supplied block
  # with (controller_id, properties_array) and expects a normalised value
  # back.  Returns the common value if all controllers agree, or the first
  # non-matching value to trigger a Puppet change.  Returns nil when no
  # controllers are found.
  def read_property(setting, &block)
    values = {}
    controller_ids.each do |cid|
      props = show_property_for(cid, setting)
      values[cid] = block.call(cid, props)
    end

    return nil if values.empty?
    return values.values.first if values.values.uniq.size == 1

    # Controllers disagree — return first value that differs from the majority
    # so Puppet considers it out of sync and triggers a set.
    values.values.first
  end

  # --- Value conversion helpers ---

  # Convert a Puppet boolean (:true/:false/true/false) to storcli 'on'/'off'.
  def bool_to_onoff(val)
    (val == :true || val == true) ? 'on' : 'off'
  end

  # Convert storcli 'ON'/'OFF' to a Puppet symbol :true/:false.
  def onoff_to_bool(val)
    val.to_s.casecmp('on').zero? ? :true : :false
  end

  # Convert storcli 'Enabled'/'Disabled' to a Puppet symbol :true/:false.
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
end
