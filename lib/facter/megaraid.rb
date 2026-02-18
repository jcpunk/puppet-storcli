# frozen_string_literal: true

#
# megaraid.rb
#
# Author: Wagner Sartori Junior <wsartori@wsartori.com>
#
require 'json'
require 'time'
require 'timeout'

# Main Megaraid class
class Megaraid
  # Is a megaraid driver present?
  def present?
    Dir.exist?('/sys/bus/pci/drivers/megaraid_sas') || Dir.exist?('/sys/bus/pci/drivers/mpt3sas')
  end

  # Find all available storcli/perccli applications
  def storcli_tools
    return @storcli_tools if defined?(@storcli_tools)
    @storcli_tools = []
    return @storcli_tools unless present?

    dmi = Facter.value(:dmi)
    manufacturer = dmi.is_a?(Hash) ? dmi['manufacturer'] : nil
    is_dell = manufacturer.is_a?(String) && manufacturer.include?('Dell')

    storcli_locations =
      if is_dell
        ['perccli2', '/opt/MegaRAID/perccli/perccli2',
         'perccli64', '/opt/MegaRAID/perccli/perccli64',
         'perccli',   '/opt/MegaRAID/perccli/perccli']
      else
        ['storcli2', '/opt/MegaRAID/storcli/storcli2',
         'storcli64', '/opt/MegaRAID/storcli/storcli64',
         'storcli',   '/opt/MegaRAID/storcli/storcli']
      end

    # Find all available tools (a system might have both storcli and storcli2)
    seen_paths = {}
    storcli_locations.each do |run|
      path = Facter::Util::Resolution.which(run)
      next unless path
      # Avoid duplicates (e.g., storcli and /usr/bin/storcli might be the same)
      next if seen_paths[path]
      seen_paths[path] = true
      @storcli_tools << path
    end

    @storcli_tools
  end

  # Return first available storcli tool for backward compatibility
  def storcli
    tools = storcli_tools
    tools.empty? ? nil : tools.first
  end

  # Get tool information (version, type) for a given tool path
  # This helps identify differences between storcli2 and storcli64
  def get_tool_info(tool)
    return @tool_info[tool] if defined?(@tool_info) && @tool_info[tool]
    
    @tool_info ||= {}
    
    # Try to get version info - storcli2 and storcli64 should both support this
    raw = Facter::Util::Resolution.exec("#{tool} show J nolog")
    return @tool_info[tool] = {} unless raw && !raw.empty?

    output = begin
               JSON.parse(raw)
             rescue StandardError
               nil
             end
    return @tool_info[tool] = {} unless output.is_a?(Hash)

    # Extract CLI version if available
    cli_version = output.dig('Controllers', 0, 'Command Status', 'CLI Version')
    tool_name = File.basename(tool)
    
    @tool_info[tool] = {
      'name' => tool_name,
      'path' => tool,
      'version' => cli_version || 'Unknown'
    }
  rescue StandardError
    @tool_info[tool] = {}
  end

  # Function to call all get methods
  def all_info
    Dir.chdir('/tmp') do
      controller_info
      pr_info
      cc_info
    end
  end

  # Get controller information from all available CLI tools
  def controller_info
    @controller_info = {}
    return unless present?
    
    tools = storcli_tools
    return if tools.empty?

    # Query each available CLI tool and combine results
    tools.each do |tool|
      # Get tool info for better error reporting
      tool_info = get_tool_info(tool)
      
      raw = Facter::Util::Resolution.exec("#{tool} /call show J nolog")
      next unless raw && !raw.empty?

      output = begin
                 JSON.parse(raw)
               rescue StandardError => e
                 # Log parse error but continue with other tools
                 Facter.debug("Failed to parse JSON from #{tool}: #{e.message}")
                 nil
               end
      next unless output.is_a?(Hash)

      # Check if the output structure is as expected
      # This helps catch differences between storcli2 and storcli64
      unless output.key?('Controllers')
        Facter.debug("Unexpected output structure from #{tool}: missing 'Controllers' key")
        next
      end

      output.fetch('Controllers', []).each do |controller|
        next if controller.dig('Command Status', 'Status') == 'Failure'
        id = controller.dig('Command Status', 'Controller')
        next if id.nil?

        # Store which tool found this controller
        controller_data = controller.fetch('Response Data', {})
        controller_data['_storcli_tool'] = tool
        controller_data['_storcli_tool_info'] = tool_info
        @controller_info[id] = controller_data
      end
    end
  end

  # Get patrol read information from all available CLI tools
  def pr_info
    @pr_info = {}
    return unless present?
    return unless num_controllers.positive?
    
    tools = storcli_tools
    return if tools.empty?

    # Query each available CLI tool
    tools.each do |tool|
      raw = Facter::Util::Resolution.exec("#{tool} /call show patrolread J nolog")
      next unless raw && !raw.empty?

      output = begin
                 JSON.parse(raw)
               rescue StandardError => e
                 Facter.debug("Failed to parse patrol read JSON from #{tool}: #{e.message}")
                 nil
               end
      next unless output.is_a?(Hash)

      # Validate expected structure
      unless output.key?('Controllers')
        Facter.debug("Unexpected patrol read output from #{tool}: missing 'Controllers' key")
        next
      end

      output.fetch('Controllers', []).each do |controller|
        pr_properties = {}
        controller_properties = controller.dig('Response Data', 'Controller Properties') || {}

        if controller_properties.empty?
          pr_properties['mode'] = 'Un-supported'
          pr_properties['next_start_time'] = 'Un-supported'
        else
          controller_properties.each do |attribute|
            key = attribute['Ctrl_Prop']
            val = attribute['Value']

            case key
            when 'PR Mode'
              pr_properties['mode'] = val
            when 'PR Execution Delay'
              pr_properties['execution_delay'] = val.to_i
            when 'PR on SSD'
              pr_properties['on_ssd'] = (val != 'Disabled')
            when 'PR Next Start time'
              begin
                t = Time.strptime(val, '%m/%d/%Y, %H:%M:%S')
                pr_properties['next_start_time'] = t.strftime('%A at %H:%M:%S')
              rescue StandardError
                pr_properties['next_start_time'] = val
              end
            end
          end
        end

        id = controller.dig('Command Status', 'Controller')
        @pr_info[id] = pr_properties if id
      end
    end
  end

  # Get consistency check information from all available CLI tools
  def cc_info
    @cc_info = {}
    return unless present?
    return unless num_controllers.positive?
    
    tools = storcli_tools
    return if tools.empty?

    # Query each available CLI tool
    tools.each do |tool|
      raw = Facter::Util::Resolution.exec("#{tool} /call show cc J nolog")
      next unless raw && !raw.empty?

      output = begin
                 JSON.parse(raw)
               rescue StandardError => e
                 Facter.debug("Failed to parse consistency check JSON from #{tool}: #{e.message}")
                 nil
               end
      next unless output.is_a?(Hash)

      # Validate expected structure
      unless output.key?('Controllers')
        Facter.debug("Unexpected consistency check output from #{tool}: missing 'Controllers' key")
        next
      end

      output.fetch('Controllers', []).each do |controller|
        cc_properties = {}
        controller_properties =
          controller.dig('Response Data', 'Controller Properties') || {}

        if controller_properties.empty?
          cc_properties['operation_mode'] = 'Un-supported'
          cc_properties['next_start_time'] = 'Un-supported'
        else
          controller_properties.each do |attribute|
            key = attribute['Ctrl_Prop']
            val = attribute['Value']

            case key
            when 'CC Operation Mode'
              cc_properties['operation_mode'] = val
            when 'CC Execution Delay'
              cc_properties['execution_delay'] = val.to_i
            when 'CC Next Starttime'
              begin
                t = Time.strptime(val, '%m/%d/%Y, %H:%M:%S')
                cc_properties['next_start_time'] = t.strftime('%A at %H:%M:%S')
              rescue StandardError
                cc_properties['next_start_time'] = val
              end
            end
          end
        end

        id = controller.dig('Command Status', 'Controller')
        @cc_info[id] = cc_properties if id
      end
    end
  end

  # Number of controllers
  def num_controllers
    @controller_info.size
  end

  # Parse and returns controllers information
  def controllers_info
    ctrls = {}

    @controller_info.each do |controller, parameters|
      vd = {}

      # Get the tool that found this controller
      tool = parameters.fetch('_storcli_tool', storcli_tools.first)

      # Handle VD LIST - may be null for JBOD-only controllers
      vd_list = parameters.fetch('VD LIST', [])
      vd_list.each do |item|
        # Support both 'DG/VD' (newer) and 'VD' (older) keys
        vd_id = if item.key?('DG/VD')
                  item['DG/VD'].split('/')[1]
                elsif item.key?('VD')
                  item['VD'].to_s
                else
                  next
                end

        vd[vd_id] = {}

        raw = Facter::Util::Resolution.exec(
          "#{tool} /c#{controller}/v#{vd_id} show all J nolog",
        )
        next unless raw && !raw.empty?

        vd_json = begin
                    JSON.parse(raw)
                  rescue StandardError
                    nil
                  end
        next unless vd_json

        vd_output =
          vd_json.fetch('Controllers', [])[0]
                 &.dig('Response Data', "VD#{vd_id} Properties") || {}

        vd[vd_id]['type']       = item.fetch('TYPE', nil)
        vd[vd_id]['state']      = item.fetch('State', nil)
        vd[vd_id]['strip_size'] = vd_output.fetch('Strip Size', nil)
        vd[vd_id]['size']       = item.fetch('Size', nil)

        cache = item['Cache'].to_s.upcase

        write_cache =
          if cache.include?('AWB')
            'awb'
          elsif cache.include?('WB')
            'wb'
          elsif cache.include?('WT')
            'wt'
          else
            'unknown'
          end

        vd[vd_id]['write_cache'] = write_cache

        if cache.start_with?('R')
          vd[vd_id]['read_cache'] = 'ra'
        elsif cache.start_with?('NR')
          vd[vd_id]['read_cache'] = 'nora'
        end

        if cache.end_with?('D')
          vd[vd_id]['io_policy'] = 'direct'
        elsif cache.end_with?('C')
          vd[vd_id]['io_policy'] = 'cached'
        end

        pdc = vd_output.fetch('Disk Cache Policy', 'unknown')
        vd[vd_id]['physical_drive_cache'] =
          case pdc
          when "Disk's Default" then 'default'
          when 'Enabled'        then 'on'
          when 'Disabled'       then 'off'
          else pdc
          end

        vd[vd_id]['name']       = item.fetch('Name', nil)
        vd[vd_id]['encryption'] = vd_output.fetch('Encryption', nil)
      end

      ctrls[controller] = {
        'product_name'  => parameters.fetch('Product Name', nil),
        'serial_number' => parameters.fetch('Serial Number', nil),

        'fw_package_build' => parameters.fetch('FW Package Build', nil),
        'fw_version'       => parameters.fetch('FW Version', nil),
        'bios_version'     => parameters.fetch('BIOS Version', nil),

        'driver_name'           => parameters.fetch('Driver Name', nil),
        'device_interface'      => parameters.fetch('Device Interface', nil),
        'drive_groups'          => parameters.fetch('Drive Groups', nil),
        'physical_drive_count'  => parameters.fetch('Physical Drives', nil),

        'virtual_drives'   => vd,
        'patrol_read'      => @pr_info[controller],
        'consistency_check' => @cc_info[controller],
      }
      # Note: _storcli_tool and _storcli_tool_info are intentionally not included in output (internal use only)
    end

    ctrls
  end

  def all_facts
    all_info

    # Collect tool information for debugging/visibility
    tools_with_info = storcli_tools.map do |tool|
      info = get_tool_info(tool)
      {
        'path' => tool,
        'name' => info['name'] || File.basename(tool),
        'version' => info['version'] || 'Unknown'
      }
    end

    {
      'present'               => present?,
      'storcli'               => storcli,
      'storcli_tools'         => storcli_tools,
      'tool_info'             => tools_with_info,
      'number_of_controllers' => num_controllers,
      'controllers'           => controllers_info,
    }
  end
end

Facter.add(:megaraid) do
  confine kernel: 'Linux'

  setcode do
    # Timeout to prevent fact from hanging indefinitely on slow/hung storcli commands
    # This protects Puppet runs from blocking on hardware issues
    Timeout.timeout(60) do
      Megaraid.new.all_facts
    end
  rescue Timeout::Error
    Facter.warn('megaraid fact collection timed out after 60 seconds')
    {
      'present' => false,
      'storcli' => nil,
      'storcli_tools' => [],
      'tool_info' => [],
      'number_of_controllers' => 0,
      'controllers' => {},
      'error' => 'Fact collection timed out'
    }
  rescue StandardError => e
    Facter.warn("megaraid fact collection failed: #{e.message}")
    {
      'present' => false,
      'storcli' => nil,
      'storcli_tools' => [],
      'tool_info' => [],
      'number_of_controllers' => 0,
      'controllers' => {},
      'error' => e.message
    }
  end
end
