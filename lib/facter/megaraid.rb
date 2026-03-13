# frozen_string_literal: true

#
# megaraid.rb
#
# Author: Wagner Sartori Junior <wsartori@wsartori.com>
#
require 'json'
require 'time'

# Main Megaraid class
class Megaraid
  # Is a megaraid driver present?
  def present?
    Dir.exist?('/sys/bus/pci/drivers/megaraid_sas') || Dir.exist?('/sys/bus/pci/drivers/mpt3sas')
  end

  # where's storcli application
  def storcli
    return @storcli if defined?(@storcli)
    @storcli = nil
    return unless present?

    dmi = Facter.value(:dmi)
    manufacturer = dmi.is_a?(Hash) ? dmi['manufacturer'] : nil
    is_dell = manufacturer.is_a?(String) && manufacturer.include?('Dell')

    storcli_locations =
      if is_dell
        ['perccli64', '/opt/MegaRAID/perccli/perccli64',
         'perccli',   '/opt/MegaRAID/perccli/perccli']
      else
        ['storcli64', '/opt/MegaRAID/storcli/storcli64',
         'storcli',   '/opt/MegaRAID/storcli/storcli']
      end

    storcli_locations.each do |run|
      path = Facter::Util::Resolution.which(run)
      next unless path
      @storcli = path
      break
    end

    @storcli
  end

  # Function to call all get methods
  def all_info
    Dir.chdir('/tmp') do
      controller_info
      controller_settings_info
      bbu_info
      pd_summary_info
      vd_properties_info
      pr_info
      cc_info
    end
  end

  # Get controller information
  def controller_info
    @controller_info = {}
    return unless present?
    return unless storcli

    raw = Facter::Util::Resolution.exec("#{storcli} /call show J nolog")
    return unless raw && !raw.empty?

    output = begin
               JSON.parse(raw)
             rescue
               nil
             end
    return unless output.is_a?(Hash)

    output.fetch('Controllers', []).each do |controller|
      next if controller.dig('Command Status', 'Status') == 'Failure'
      id = controller.dig('Command Status', 'Controller')
      next if id.nil?

      @controller_info[id] = controller.fetch('Response Data', {})
    end
  end

  # Get controller settings information
  def controller_settings_info
    @controller_settings = {}
    return unless present?
    return unless storcli
    return unless defined?(@controller_info) && !@controller_info.empty?

    @controller_info.each_key do |controller_id|
      settings = {}
      
      raw = Facter::Util::Resolution.exec("#{storcli} /c#{controller_id} show all J nolog")
      next unless raw && !raw.empty?

      output = begin
                 JSON.parse(raw)
               rescue
                 nil
               end
      next unless output.is_a?(Hash)

      controller_data = output.fetch('Controllers', [])[0]
      next unless controller_data
      
      response_data = controller_data.dig('Response Data') || {}
      
      # Extract controller properties which contain settings
      controller_props = response_data.dig('Controller Properties') || {}
      
      # Parse each setting, marking as Un-supported if not present
      if controller_props.empty?
        # If we can't get settings, mark as unsupported
        settings['Auto Rebuild'] = 'Un-supported'
        settings['Copy Back'] = 'Un-supported'
        settings['JBOD'] = 'Un-supported'
      else
        controller_props.each do |prop|
          key = prop['Ctrl_Prop']
          val = prop['Value']
          
          # Capture all relevant settings
          case key
          when 'Auto Rebuild',
               'Copy Back',
               'NCQ Status',
               'Boot With Pinned Cache',
               'Alarm',
               'Load Balance Mode',
               'Abort CC on Error',
               'Maintain PD Fail History',
               'Restore Hot Spare on Insertion',
               'Spin Down Unconfigured Drives',
               'Coercion Mode',
               'Enclosure Power Down',
               'JBOD'
            settings[key] = val
          when 'Rebuild Rate',
               'Performance Mode',
               'Cache Flush Interval',
               'SMART Mode',
               'SMART Poll Interval',
               'BGI Rate',
               'Spin Up Drive Count',
               'Spin Up Delay'
            # Store numeric values as integers
            settings[key] = val.to_i
          end
        end
        
        # Add sentinel for settings not found in output
        default_settings = [
          'Auto Rebuild', 'Copy Back', 'NCQ Status', 
          'Boot With Pinned Cache', 'Alarm', 'JBOD',
          'Load Balance Mode', 'Rebuild Rate', 
          'Performance Mode', 'Cache Flush Interval',
          'SMART Poll Interval'
        ]
        
        default_settings.each do |setting_name|
          settings[setting_name] ||= 'Un-supported'
        end
      end
      
      @controller_settings[controller_id] = settings
    end
  end

  # Get BBU/CacheVault health information
  def bbu_info
    @bbu_info = {}
    return unless present?
    return unless storcli
    return unless defined?(@controller_info) && !@controller_info.empty?

    @controller_info.each_key do |controller_id|
      bbu_health = {}
      
      raw = Facter::Util::Resolution.exec("#{storcli} /c#{controller_id}/bbu show all J nolog")
      
      if raw.nil? || raw.empty? || raw.include?('does not have BBU')
        # No BBU present or not supported
        bbu_health['state'] = 'Un-supported'
        bbu_health['type'] = 'Un-supported'
        bbu_health['charge_percent'] = 'Un-supported'
        bbu_health['replacement_needed'] = 'Un-supported'
      else
        output = begin
                   JSON.parse(raw)
                 rescue
                   nil
                 end
        
        if output.is_a?(Hash)
          controller_data = output.fetch('Controllers', [])[0]
          if controller_data
            response_data = controller_data.dig('Response Data') || {}
            bbu_props = response_data.dig('BBU_Info', 0) || {}
            
            bbu_health['state'] = bbu_props['State'] || 'Unknown'
            bbu_health['type'] = bbu_props['Model'] || 'BBU'
            bbu_health['charge_percent'] = bbu_props['Relative State of Charge'] || 'Unknown'
            bbu_health['replacement_needed'] = (bbu_props['Pack is about to fail & should be replaced'] == 'Yes')
            bbu_health['learn_cycle_active'] = (bbu_props['Learn Cycle Active'] == 'Yes')
            bbu_health['temperature'] = bbu_props['Temperature'] || 'Unknown'
          end
        end
      end
      
      @bbu_info[controller_id] = bbu_health
    end
  end

  # Get physical drive summary information
  def pd_summary_info
    @pd_summary = {}
    return unless present?
    return unless storcli
    return unless defined?(@controller_info) && !@controller_info.empty?

    @controller_info.each_key do |controller_id|
      summary = {
        'total_drives' => 0,
        'drives_by_state' => {},
        'drives_by_type' => {},
        'drives_by_media' => {},
        'total_capacity_gb' => 0,
        'predictive_failures' => 0
      }
      
      raw = Facter::Util::Resolution.exec("#{storcli} /c#{controller_id}/eall/sall show all J nolog")
      next unless raw && !raw.empty?

      output = begin
                 JSON.parse(raw)
               rescue
                 nil
               end
      next unless output.is_a?(Hash)

      controller_data = output.fetch('Controllers', [])[0]
      next unless controller_data
      
      response_data = controller_data.dig('Response Data') || {}
      
      # Iterate through each drive
      response_data.each do |key, value|
        next unless key.start_with?('Drive /c')
        next unless value.is_a?(Array)
        
        value.each do |drive_info|
          next unless drive_info.is_a?(Hash)
          
          summary['total_drives'] += 1
          
          # Count by state
          state = drive_info['State'] || 'Unknown'
          summary['drives_by_state'][state] ||= 0
          summary['drives_by_state'][state] += 1
          
          # Count by interface type
          intf = drive_info['Intf'] || 'Unknown'
          summary['drives_by_type'][intf] ||= 0
          summary['drives_by_type'][intf] += 1
          
          # Count by media type
          media = drive_info['Med'] || 'Unknown'
          summary['drives_by_media'][media] ||= 0
          summary['drives_by_media'][media] += 1
          
          # Sum capacity
          size_str = drive_info['Size'] || '0 GB'
          if size_str =~ /([\d.]+)\s*([GT]B)/
            size = $1.to_f
            unit = $2
            size_gb = (unit == 'TB') ? size * 1024 : size
            summary['total_capacity_gb'] += size_gb
          end
          
          # Count predictive failures
          pred_fail = drive_info['Pred Fail'] || '0'
          summary['predictive_failures'] += 1 if pred_fail.to_i > 0
        end
      end
      
      # Format capacity nicely
      if summary['total_capacity_gb'] > 1024
        summary['total_capacity'] = "#{(summary['total_capacity_gb'] / 1024.0).round(2)} TB"
      else
        summary['total_capacity'] = "#{summary['total_capacity_gb'].round(2)} GB"
      end
      summary.delete('total_capacity_gb')
      
      @pd_summary[controller_id] = summary
    end
  end

  # Get virtual drive properties information
  def vd_properties_info
    @vd_properties = {}
    return unless present?
    return unless storcli
    return unless defined?(@controller_info) && !@controller_info.empty?

    @controller_info.each_key do |controller_id|
      vd_props = {}
      
      # Get list of VDs first
      raw = Facter::Util::Resolution.exec("#{storcli} /c#{controller_id}/vall show all J nolog")
      next unless raw && !raw.empty?

      output = begin
                 JSON.parse(raw)
               rescue
                 nil
               end
      next unless output.is_a?(Hash)

      controller_data = output.fetch('Controllers', [])[0]
      next unless controller_data
      
      response_data = controller_data.dig('Response Data') || {}
      
      # Process each VD
      response_data.each do |key, value|
        next unless key.start_with?('/c') && key.include?('/v')
        next unless value.is_a?(Array)
        
        vd_id = key.split('/v').last
        
        value.each do |vd_info|
          next unless vd_info.is_a?(Hash)
          
          props = {}
          
          # Static configuration properties
          props['stripe_size'] = vd_info['Strip Size'] || 'Unknown'
          props['span_depth'] = vd_info['Span Depth'] || 'Unknown'
          props['number_of_drives_per_span'] = vd_info['Number Of Drives per span'] || vd_info['Number Of Drives'] || 'Unknown'
          
          # Cache policies
          props['default_cache_policy'] = vd_info['Default Cache Policy'] || 'Unknown'
          props['current_cache_policy'] = vd_info['Current Cache Policy'] || 'Unknown'
          props['default_write_policy'] = vd_info['Default Write Policy'] || 'Unknown'
          props['current_write_policy'] = vd_info['Current Write Policy'] || 'Unknown'
          props['default_read_policy'] = vd_info['Default Read Policy'] || 'Unknown'
          props['current_read_policy'] = vd_info['Current Read Policy'] || 'Unknown'
          
          # Other properties
          props['is_vd_boot_drive'] = vd_info['Boot Drive'] || 'No'
          props['disk_cache_policy'] = vd_info['Disk Cache Policy'] || 'Unknown'
          
          vd_props[vd_id] = props
        end
      end
      
      @vd_properties[controller_id] = vd_props
    end
  end

  # Get patrol read information
  def pr_info
    @pr_info = {}
    return unless present?
    return unless storcli
    return unless num_controllers.positive?

    raw = Facter::Util::Resolution.exec("#{storcli} /call show patrolread J nolog")
    return unless raw && !raw.empty?

    output = begin
               JSON.parse(raw)
             rescue
               nil
             end
    return unless output.is_a?(Hash)

    output.fetch('Controllers', []).each do |controller|
      pr_properties = {}
      controller_properties = controller.dig('Response Data', 'Controller Properties') || {}

      if controller_properties.empty?
        pr_properties['PR Mode'] = 'Un-supported'
        pr_properties['PR Next Start time'] = 'Un-supported'
      else
        controller_properties.each do |attribute|
          key = attribute['Ctrl_Prop']
          val = attribute['Value']

          case key
          when 'PR Execution Delay',
                 'PR iterations completed',
                 'PR MaxConcurrentPd'
            pr_properties[key] = val.to_i
          when 'PR on SSD'
            pr_properties[key] = (val != 'Disabled')
          when 'PR Next Start time'
            begin
              t = Time.strptime(val, '%m/%d/%Y, %H:%M:%S')
              pr_properties[key] = t.strftime('%A at %H:%M:%S')
            rescue
              pr_properties[key] = val
            end
          else
            pr_properties[key] = val
          end
        end
      end

      id = controller.dig('Command Status', 'Controller')
      @pr_info[id] = pr_properties if id
    end
  end

  # Get consistency check information
  def cc_info
    @cc_info = {}
    return unless present?
    return unless storcli
    return unless num_controllers.positive?

    raw = Facter::Util::Resolution.exec("#{storcli} /call show cc J nolog")
    return unless raw && !raw.empty?

    output = begin
               JSON.parse(raw)
             rescue
               nil
             end
    return unless output.is_a?(Hash)

    output.fetch('Controllers', []).each do |controller|
      cc_properties = {}
      controller_properties =
        controller.dig('Response Data', 'Controller Properties') || {}

      if controller_properties.empty?
        cc_properties['CC Operation Mode'] = 'Un-supported'
        cc_properties['CC Next Starttime'] = 'Un-supported'
      else
        controller_properties.each do |attribute|
          key = attribute['Ctrl_Prop']
          val = attribute['Value']

          case key
          when 'CC Execution Delay',
                 'CC Number of iterations',
                 'CC Number of VD completed'
            cc_properties[key] = val.to_i
          when 'CC Next Starttime'
            begin
              t = Time.strptime(val, '%m/%d/%Y, %H:%M:%S')
              cc_properties[key] = t.strftime('%A at %H:%M:%S')
            rescue
              cc_properties[key] = val
            end
          else
            cc_properties[key] = val
          end
        end
      end

      id = controller.dig('Command Status', 'Controller')
      @cc_info[id] = cc_properties if id
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

      parameters.fetch('VD LIST', []).each do |item|
        next unless item.key?('DG/VD')

        vd_id = item['DG/VD'].split('/')[1]
        vd[vd_id] = {}

        raw = Facter::Util::Resolution.exec(
          "#{storcli} /c#{controller}/v#{vd_id} show all J nolog",
        )
        next unless raw && !raw.empty?

        vd_json = begin
                    JSON.parse(raw)
                  rescue
                    nil
                  end
        next unless vd_json

        vd_output =
          vd_json.fetch('Controllers', [])[0]
                 &.dig('Response Data', "VD#{vd_id} Properties") || {}

        vd[vd_id]['Type']       = item.fetch('TYPE', nil)
        vd[vd_id]['State']      = item.fetch('State', nil)
        vd[vd_id]['Strip Size'] = vd_output.fetch('Strip Size', nil)

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

        vd[vd_id]['Write Cache'] = write_cache

        if cache.start_with?('R')
          vd[vd_id]['Read Cache'] = 'ra'
        elsif cache.start_with?('NR')
          vd[vd_id]['Read Cache'] = 'nora'
        end

        if cache.end_with?('D')
          vd[vd_id]['IO Policy'] = 'direct'
        elsif cache.end_with?('C')
          vd[vd_id]['IO Policy'] = 'cached'
        end

        pdc = vd_output.fetch('Disk Cache Policy', 'unknown')
        vd[vd_id]['Physical Drive Cache'] =
          case pdc
          when "Disk's Default" then 'default'
          when 'Enabled'        then 'on'
          when 'Disabled'       then 'off'
          else pdc
          end

        vd[vd_id]['Name']       = item.fetch('Name', nil)
        vd[vd_id]['Encryption'] = vd_output.fetch('Encryption', nil)
      end

      ctrls[controller] = {
        'product_name'  => parameters.fetch('Product Name', nil),
        'serial_number' => parameters.fetch('Serial Number', nil),

        'fw_package_build' => parameters.fetch('FW Package Build', nil),
        'fw_version'       => parameters.fetch('FW Version', nil),
        'bios_version'     => parameters.fetch('BIOS Version', nil),

        'virtual_drives'    => vd,
        'patrol_read'       => @pr_info[controller],
        'consistency_check' => @cc_info[controller],
        'controller_settings' => @controller_settings&.fetch(controller, {}),
        'bbu_info' => @bbu_info&.fetch(controller, {}),
        'physical_drive_summary' => @pd_summary&.fetch(controller, {}),
        'vd_properties' => @vd_properties&.fetch(controller, {}),
      }
    end

    ctrls
  end

  def all_facts
    storcli
    all_info

    {
      'present?'              => present?,
      'storcli'               => storcli,
      'number_of_controllers' => num_controllers,
      'controllers'           => controllers_info,
    }
  end
end

Facter.add(:megaraid) do
  confine kernel: 'Linux'

  setcode do
    Megaraid.new.all_facts
  end
end
