# frozen_string_literal: true

require 'json'

Puppet::Type.type(:megaraid_vd_setting).provide(:storcli) do
  desc 'Manages MegaRAID virtual drive settings via storcli/perccli'

  commands storcli_cmd: 'storcli64'

  def self.storcli
    @storcli ||= begin
      facts = Facter.value(:megaraid)
      if facts && facts['storcli']
        facts['storcli']
      else
        'storcli64'
      end
    end
  end

  def storcli
    self.class.storcli
  end

  def vd_path
    "/c#{resource[:controller]}/v#{resource[:vd]}"
  end

  def exists?
    # Always return true as we're managing properties, not existence
    true
  end

  def create
    # Not used - we manage properties instead
  end

  def destroy
    # Not used - settings cannot be destroyed
  end

  def value
    # For 'all' VDs, we can't easily check current state, so we'll always apply
    return :absent if resource[:vd] == 'all'

    current_value = get_current_value
    Puppet.debug("megaraid_vd_setting: current value for #{resource[:setting]} on VD #{resource[:controller]}/#{resource[:vd]}: #{current_value}")
    current_value
  end

  def value=(new_value)
    set_value(new_value)
  end

  private

  def get_current_value
    setting = resource[:setting]
    
    # Get VD info from facts
    facts = Facter.value(:megaraid)
    return :absent unless facts && facts['controllers']
    
    controller_info = facts['controllers'][resource[:controller]]
    return :absent unless controller_info && controller_info['virtual_drives']
    
    vd_info = controller_info['virtual_drives'][resource[:vd].to_s]
    return :absent unless vd_info

    case setting
    when 'wrcache'
      vd_info['Write Cache']
    when 'rdcache'
      vd_info['Read Cache']
    when 'iopolicy'
      vd_info['IO Policy']
    when 'pdcache'
      vd_info['Physical Drive Cache']
    else
      :absent
    end
  rescue StandardError => e
    Puppet.warning("Failed to get current value for #{setting}: #{e.message}")
    :absent
  end

  def set_value(new_value)
    setting = resource[:setting]
    execute_command("set #{setting}=#{new_value}")
  end

  def execute_command(cmd)
    full_cmd = "#{storcli} #{vd_path} #{cmd} nolog"
    Puppet.debug("Executing: #{full_cmd}")
    output = execute(full_cmd.split(' '), failonfail: true, combine: true)
    Puppet.debug("Command output: #{output}")
    output
  end
end
