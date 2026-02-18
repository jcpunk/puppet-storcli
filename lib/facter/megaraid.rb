# frozen_string_literal: true

# megaraid.rb — Facter structured fact for MegaRAID / Dell PERC controllers
#
# Returns $facts['megaraid'] as a hash. If no controller is present, or if
# collection times out, returns a minimal hash with 'present' => false.
#
# Fact structure (keys are absent when not applicable):
#
#   megaraid:
#     present:               bool
#     storcli_tools:         ['/usr/bin/storcli2', ...]
#     number_of_controllers: int
#     controllers:
#       <id>:
#         product_name, serial_number, fw_*, bios_version,
#         driver_name, device_interface, drive_groups_count,
#         physical_drive_count, storcli_tool
#         drive_groups:
#           <dg_id>:
#             virtual_disks:
#               <vd_id>: { name, raid_level, size, state, properties: {...} }
#         controller_settings: { <Ctrl_Prop key> => value, ... }
#         bbu_info:           { state, [type, replacement_needed, learn_cycle_active] }
#         patrol_read:        { mode, execution_delay, on_ssd, next_start_time }
#         consistency_check:  { operation_mode, execution_delay, next_start_time }
#
# Design notes:
#  - Dell systems use perccli; all others use storcli. PERC cards are assumed
#    to only appear in Dell hardware and vice versa.
#
# Authors:
#   Wagner Sartori Junior <wsartori@wsartori.com>
#   Pat Riehecky <riehecky@fnal.gov>

require 'json'
require 'time'
require 'timeout'

class Megaraid

  # Hardware presence detection
  def present?
    Dir.exist?('/sys/bus/pci/drivers/megaraid_sas') || Dir.exist?('/sys/bus/pci/drivers/mpt3sas')
  end

  # CLI tool discovery
  def storcli_tools
    return @storcli_tools if defined?(@storcli_tools)
    @storcli_tools = []
    return @storcli_tools unless present?

    is_dell = Facter.value(:dmi)&.dig('manufacturer')&.include?('Dell') || false

    candidates =
      if is_dell
        [
         'perccli64', '/opt/MegaRAID/perccli/perccli64',
         'perccli',   '/opt/MegaRAID/perccli/perccli']
      else
        [
         'storcli64', '/opt/MegaRAID/storcli/storcli64',
         'storcli',   '/opt/MegaRAID/storcli/storcli']
      end

    seen = {}
    candidates.each do |name|
      path = Facter::Util::Resolution.which(name)
      next unless path
      next if seen[path]
      seen[path] = true
      @storcli_tools << path
    end

    @storcli_tools
  end

  # Low-level exec helpers

  # Runs `tool args` and returns the parsed JSON, or nil on empty output or
  # parse failure. Parse errors are logged at debug level so they appear with
  # `facter --debug` without cluttering normal Puppet runs.
  def exec_json(tool, args)
    raw = Facter::Util::Resolution.exec("#{tool} #{args}")
    return nil unless raw && !raw.empty?

    JSON.parse(raw)
  rescue JSON::ParserError => e
    Facter.debug("megaraid: JSON parse error from `#{tool} #{args}`: #{e.message}")
    nil
  end

  # Yields (tool, controller_hash) for every controller entry returned across
  # all discovered CLI tools for the given storcli argument string.
  #
  # Centralises the repetitive pattern that every collector needs:
  #   storcli_tools.each → exec_json → output['Controllers'].each
  def each_controller_response(args)
    storcli_tools.each do |tool|
      output = exec_json(tool, args)
      next unless output.is_a?(Hash)

      output.fetch('Controllers', []).each { |ctrl| yield tool, ctrl }
    end
  end

  # Per-controller data collectors

  # Populates @controller_info: a hash keyed by controller ID whose values are
  # the raw 'Response Data' hashes with '_storcli_tool' appended.
  def collect_controller_info
    @controller_info = {}

    each_controller_response('/call show J nolog') do |tool, controller|
      next if controller.dig('Command Status', 'Status') == 'Failure'

      id = controller.dig('Command Status', 'Controller')
      next unless id

      data = controller.fetch('Response Data', {})
      data['_storcli_tool'] = tool
      @controller_info[id] = data
    end
  end

  # Safe accessor for controller count; returns 0 before collect_controller_info runs.
  def num_controllers
    (@controller_info || {}).size
  end

  # Parses a storcli schedule time string ("MM/DD/YYYY, HH:MM:SS") into a
  # human-readable form ("Monday at 14:30:00").
  # Falls back to the original string if parsing fails so data is never silently lost.
  def parse_schedule_time(val)
    Time.strptime(val, '%m/%d/%Y, %H:%M:%S').strftime('%A at %H:%M:%S')
  rescue StandardError
    val
  end

  # Populates @pr_info: patrol read schedule keyed by controller ID.
  def collect_pr_info
    @pr_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show patrolread J nolog') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      props = controller.dig('Response Data', 'Controller Properties') || []
      next if props.empty?   # controller does not support patrol read

      pr = {}
      props.each do |attr|
        case attr['Ctrl_Prop']
        when 'PR Mode'            then pr['mode']            = attr['Value']
        when 'PR Execution Delay' then pr['execution_delay'] = attr['Value'].to_i
        when 'PR on SSD'          then pr['on_ssd']          = (attr['Value'] != 'Disabled')
        when 'PR Next Start time' then pr['next_start_time'] = parse_schedule_time(attr['Value'])
        end
      end

      @pr_info[id] = pr
    end
  end

  # Populates @cc_info: consistency check schedule keyed by controller ID.
  def collect_cc_info
    @cc_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show cc J nolog') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      props = controller.dig('Response Data', 'Controller Properties') || []
      next if props.empty?

      cc = {}
      props.each do |attr|
        case attr['Ctrl_Prop']
        when 'CC Operation Mode'  then cc['operation_mode']  = attr['Value']
        when 'CC Execution Delay' then cc['execution_delay'] = attr['Value'].to_i
        when 'CC Next Starttime'  then cc['next_start_time'] = parse_schedule_time(attr['Value'])
        end
      end

      @cc_info[id] = cc
    end
  end

  # Populates @controller_settings_info: all raw controller properties keyed
  # by controller ID. Numeric strings are coerced to integers; everything else
  # stays as a string.
  def collect_controller_settings
    @controller_settings_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show all J nolog') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      settings = {}
      props = controller.dig('Response Data', 'Controller Properties') || []
      props.each do |attr|
        key = attr['Ctrl_Prop']
        val = attr['Value']
        settings[key] = Integer(val, 10)
      rescue ArgumentError
        settings[key] = val
      end

      @controller_settings_info[id] = settings
    end
  end

  # Populates @bbu_info: battery backup unit state keyed by controller ID.
  def collect_bbu_info
    @bbu_info = {}
    return unless num_controllers.positive?

    each_controller_response('/call show bbu J nolog') do |_tool, controller|
      id = controller.dig('Command Status', 'Controller')
      next unless id

      # Key name varies between storcli versions: 'BBU_Info' (newer) vs 'BBU Info' (older)
      bbu_raw = controller.dig('Response Data', 'BBU_Info') ||
                controller.dig('Response Data', 'BBU Info') ||
                {}

      next if bbu_raw.empty?

      @bbu_info[id] =
          {
            'state'              => bbu_raw.fetch('State', 'Unknown'),
            # 'Model' in newer storcli; 'Type' in older storcli
            'type'               => bbu_raw.fetch('Model', nil) || bbu_raw.fetch('Type', 'BBU'),
            'replacement_needed' => (bbu_raw.fetch('Battery Replacement required', 'No') == 'Yes'),
            'learn_cycle_active' => (bbu_raw.fetch('Learn Cycle Requested', 'No') != 'No'),
          }
        end
    end
  end

  # Virtual disk / drive group assembly

  # Parses the compact 'Cache' token from the VD LIST entry into discrete
  # policy symbols.
  def parse_cache_string(cache)
    c = cache.to_s.upcase

    write =
      if c.include?('AWB') then 'awb'
      elsif c.include?('WB') then 'wb'
      elsif c.include?('WT') then 'wt'
      end

    read =
      if c.start_with?('NR') then 'nora'   # NR must be tested before R
      elsif c.start_with?('R') then 'ra'
      end

    io =
      if c.end_with?('D') then 'Direct'
      elsif c.end_with?('C') then 'Cached'
      end

    { write: write, read: read, io: io }.compact
  end

  # Queries per-VD detail and assembles the drive_groups subtree for one
  # controller. Returns { dg_id => { 'virtual_disks' => { vd_id => {...} } } }.
  def build_drive_groups(controller_id, tool, vd_list)
    drive_groups = {}

    vd_list.each do |item|
      # Newer storcli uses 'DG/VD' (e.g. "0/0"); older uses plain 'VD'.
      # Normalise to (dg_id, vd_id) string pair in both cases.
      if item.key?('DG/VD')
        dg_id, vd_id = item['DG/VD'].split('/')
      elsif item.key?('VD')
        dg_id = '0'
        vd_id = item['VD'].to_s
      else
        next
      end

      drive_groups[dg_id] ||= { 'virtual_disks' => {} }

      vd_detail = exec_json(tool, "/c#{controller_id}/v#{vd_id} show all J nolog")
      vd_props  = vd_detail
                    &.fetch('Controllers', [])
                    &.first
                    &.dig('Response Data', "VD#{vd_id} Properties") || {}

      cache = parse_cache_string(item['Cache'])

      # Map short cache tokens to the verbose names storcli uses elsewhere
      # for consistency when consumers compare policies across code paths.
      write_policy =
        case cache[:write]
        when 'wb', 'awb' then 'WriteBack'
        when 'wt'        then 'WriteThrough'
        end

      read_policy = (cache[:read] == 'ra') ? 'ReadAhead' : 'ReadAheadNone'

      # Disk Cache Policy uses verbose strings in storcli output; normalise
      # to short tokens for easier pattern matching in Puppet manifests.
      disk_cache =
        case vd_props.fetch('Disk Cache Policy', nil)
        when "Disk's Default" then 'default'
        when 'Enabled'        then 'on'
        when 'Disabled'       then 'off'
        else vd_props['Disk Cache Policy']
        end

      # Omit nil values; absent key is cleaner than nil in Facter output and
      # lets Puppet manifests use simple truthiness checks.
      properties = {
        'stripe_size'               => vd_props.fetch('Strip Size', nil),
        'span_depth'                => vd_props.fetch('Span Depth', nil),
        'number_of_drives_per_span' => vd_props.fetch('Number of Drives Per Span', nil),
        'current_write_policy'      => write_policy,
        'current_read_policy'       => read_policy,
        'io_policy'                 => cache[:io],
        'disk_cache_policy'         => disk_cache,
        'is_vd_boot_drive'          => vd_props.fetch('Is LD Ready for OS Requests', nil),
        'encryption'                => vd_props.fetch('Encryption', nil),
        'exposed_to_os'             => vd_props.fetch('Exposed to OS', nil),
        'unmap_enabled'             => vd_props.fetch('Unmap Enabled', nil),
        'data_protection'           => vd_props.fetch('Data Protection', nil),
      }.compact

      vd = {
        'name'       => "/c#{controller_id}/v#{vd_id}",
        'raid_level' => item.fetch('TYPE', nil),
        'state'      => item.fetch('State', nil),
        'size'       => item.fetch('Size', nil),
        'os_drive_name' => item.fetch('OS Drive Name', nil),
      }
      vd['properties'] = properties unless properties.empty?

      drive_groups[dg_id]['virtual_disks'][vd_id] = vd
    end

    drive_groups
  end

  # Top-level fact assembly
  def all_facts
    return { 'present' => false } unless present?

    Dir.chdir('/tmp') do
      collect_controller_info
      collect_pr_info
      collect_cc_info
      collect_controller_settings
      collect_bbu_info
    end

    return { 'present' => false } if num_controllers.zero?

    controllers = {}
    @controller_info.each do |id, params|
      tool = params.fetch('_storcli_tool', storcli_tools.first)

      # 'VD LIST' is absent on JBOD-only controllers; treat as empty.
      drive_groups = build_drive_groups(id, tool, params.fetch('VD LIST', []))

      controllers[id] = {
        'product_name'         => params.fetch('Product Name', nil),
        'serial_number'        => params.fetch('Serial Number', nil),
        'fw_package_build'     => params.fetch('FW Package Build', nil),
        'fw_version'           => params.fetch('FW Version', nil),
        'bios_version'         => params.fetch('BIOS Version', nil),
        'driver_name'          => params.fetch('Driver Name', nil),
        'device_interface'     => params.fetch('Device Interface', nil),
        'drive_groups_count'   => params.fetch('Drive Groups', nil),
        'physical_drive_count' => params.fetch('Physical Drives', nil),
        'storcli_tool'         => tool,
        'drive_groups'         => drive_groups,
        'controller_settings'  => @controller_settings_info[id],
        'bbu_info'             => @bbu_info[id],
        'patrol_read'          => @pr_info[id],
        'consistency_check'    => @cc_info[id],
      }.compact
    end

    {
      'present'               => true,
      'storcli'               => storcli_tools.first,  # backwards compat
      'number_of_controllers' => num_controllers,
      'controllers'           => controllers,
    }
  end
end

# Register fact
Facter.add(:megaraid) do
  confine kernel: 'Linux'

  setcode do
    # Guard against storcli hanging on degraded or failed hardware.
    # 60 s is generous for a heavily-loaded system with many VDs.
    Timeout.timeout(60) do
      Megaraid.new.all_facts
    end
  rescue Timeout::Error
    Facter.warn('megaraid: fact collection timed out after 60 seconds')
    { 'present' => false, 'error' => 'timeout' }
  rescue StandardError => e
    Facter.warn("megaraid: fact collection failed: #{e.message}")
    { 'present' => false, 'error' => e.message }
  end
end
