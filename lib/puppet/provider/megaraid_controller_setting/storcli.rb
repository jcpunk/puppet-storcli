# frozen_string_literal: true

require 'json'

Puppet::Type.type(:megaraid_controller_setting).provide(:storcli) do
  desc 'Manages MegaRAID controller settings via storcli/perccli'

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

  def controller_path
    "/c#{resource[:controller]}"
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
    current_value = get_current_value
    Puppet.debug("megaraid_controller_setting: current value for #{resource[:setting]} on controller #{resource[:controller]}: #{current_value}")
    current_value
  end

  def value=(new_value)
    set_value(new_value)
  end

  private

  def get_current_value
    setting = resource[:setting]

    case setting
    when 'autorebuild'
      get_boolean_setting('autorebuild', 'AutoRebuild')
    when 'copyback'
      get_boolean_setting('copyback', 'Copy Back')
    when 'jbod'
      get_boolean_setting('jbod', 'JBOD')
    when 'rebuildrate'
      get_percentage_setting('rebuildrate', 'Rebuildrate')
    when 'perfmode'
      get_numeric_setting('perfmode', 'Perf Mode')
    when 'ncq'
      get_boolean_setting('ncq', 'NCQ')
    when 'cacheflushinterval'
      get_time_setting('cacheflushint', 'Cache Flush Interval')
    when 'bootwithpinnedcache'
      get_boolean_setting('bootwithpinnedcache', 'Boot With Pinned Cache')
    when 'alarm'
      get_alarm_setting
    when 'smartpollinterval'
      get_time_setting('smartpollinterval', 'SmartPollInterval')
    else
      raise Puppet::Error, "Unknown setting: #{setting}"
    end
  rescue Puppet::ExecutionFailure => e
    Puppet.warning("Failed to get current value for #{setting}: #{e.message}")
    :absent
  end

  def set_value(new_value)
    setting = resource[:setting]

    case setting
    when 'autorebuild'
      set_boolean_setting('autorebuild', new_value)
    when 'copyback'
      set_boolean_setting('copyback', new_value)
    when 'jbod'
      set_boolean_setting('jbod', new_value)
    when 'rebuildrate'
      execute_command("set rebuildrate=#{new_value}")
    when 'perfmode'
      execute_command("set perfmode=#{new_value}")
    when 'ncq'
      set_boolean_setting('ncq', new_value)
    when 'cacheflushinterval'
      execute_command("set cacheflushint=#{new_value}")
    when 'bootwithpinnedcache'
      set_boolean_setting('bootwithpinnedcache', new_value)
    when 'alarm'
      set_boolean_setting('alarm', new_value)
    when 'smartpollinterval'
      execute_command("set smartpollinterval=#{new_value}")
    else
      raise Puppet::Error, "Unknown setting: #{setting}"
    end
  end

  def execute_command(cmd, use_json: false)
    flags = use_json ? 'J nolog' : 'nolog'
    full_cmd = "#{storcli} #{controller_path} #{cmd} #{flags}"
    Puppet.debug("Executing: #{full_cmd}")
    output = execute(full_cmd.split(' '), failonfail: true, combine: true)
    Puppet.debug("Command output: #{output}")
    output
  end

  def parse_json_response(json_str)
    data = JSON.parse(json_str)
    controllers = data.fetch('Controllers', [])
    return nil if controllers.empty?
    
    controller = controllers[0]
    return nil if controller.dig('Command Status', 'Status') == 'Failure'
    
    controller.dig('Response Data')
  rescue JSON::ParserError, StandardError => e
    Puppet.warning("Failed to parse JSON response: #{e.message}")
    nil
  end

  def get_boolean_setting(cmd, json_key)
    output = execute_command("show #{cmd}", use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    # Look for the value in Controller Properties
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == json_key }
    return :absent unless prop
    
    value = prop['Value']
    if value =~ /\bON\b/i
      'on'
    elsif value =~ /\bOFF\b/i
      'off'
    else
      :absent
    end
  end

  def get_percentage_setting(cmd, json_key)
    output = execute_command("show #{cmd}", use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == json_key }
    return :absent unless prop
    
    value = prop['Value']
    match = value.to_s.match(/(\d+)%?/)
    match ? match[1] : :absent
  end

  def get_numeric_setting(cmd, json_key)
    output = execute_command("show #{cmd}", use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == json_key }
    return :absent unless prop
    
    value = prop['Value']
    match = value.to_s.match(/(\d+)/)
    match ? match[1] : :absent
  end

  def get_time_setting(cmd, json_key)
    output = execute_command("show #{cmd}", use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == json_key }
    return :absent unless prop
    
    value = prop['Value']
    match = value.to_s.match(/(\d+)\s*sec/)
    match ? match[1] : :absent
  end

  def get_alarm_setting
    output = execute_command('show alarm', use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == 'Alarm' }
    return 'off' unless prop  # Alarm ABSENT means off
    
    value = prop['Value']
    if value =~ /\bON\b/i
      'on'
    elsif value =~ /\bOFF\b/i || value =~ /ABSENT/i
      'off'
    else
      :absent
    end
  end

  def set_boolean_setting(cmd, value)
    val_str = value.to_s.downcase == 'on' ? 'on' : 'off'
    execute_command("set #{cmd}=#{val_str}")
  end
end
