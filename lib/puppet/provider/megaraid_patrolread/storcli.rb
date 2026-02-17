# frozen_string_literal: true

require 'json'

Puppet::Type.type(:megaraid_patrolread).provide(:storcli) do
  desc 'Manages MegaRAID patrol read settings via storcli/perccli'

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

  def mode
    facts = Facter.value(:megaraid)
    return :absent unless facts && facts['controllers']
    
    controller_info = facts['controllers'][resource[:controller]]
    return :absent unless controller_info && controller_info['patrol_read']

    pr_mode = controller_info['patrol_read']['PR Mode']
    return 'off' if pr_mode =~ /Disable/i
    return 'auto' if pr_mode =~ /Auto/i
    return 'manual' if pr_mode =~ /Manual/i
    
    :absent
  rescue StandardError => e
    Puppet.warning("Failed to get patrol read mode: #{e.message}")
    :absent
  end

  def mode=(value)
    if value == 'off'
      execute_command('set patrolread=off')
    else
      execute_command("set patrolread=on mode=#{value}")
    end
  end

  def delay
    facts = Facter.value(:megaraid)
    return :absent unless facts && facts['controllers']
    
    controller_info = facts['controllers'][resource[:controller]]
    return :absent unless controller_info && controller_info['patrol_read']

    delay_value = controller_info['patrol_read']['PR Execution Delay']
    delay_value.is_a?(Integer) ? delay_value.to_s : :absent
  rescue StandardError => e
    Puppet.warning("Failed to get patrol read delay: #{e.message}")
    :absent
  end

  def delay=(value)
    execute_command("set patrolread delay=#{value}")
  end

  def rate
    output = execute_command('show prrate', use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == 'Patrol Read Rate' }
    return :absent unless prop
    
    value = prop['Value']
    match = value.to_s.match(/(\d+)%?/)
    match ? match[1] : :absent
  rescue Puppet::ExecutionFailure => e
    Puppet.warning("Failed to get patrol read rate: #{e.message}")
    :absent
  end

  def rate=(value)
    execute_command("set prrate=#{value}")
  end

  def includessds
    facts = Facter.value(:megaraid)
    return :absent unless facts && facts['controllers']
    
    controller_info = facts['controllers'][resource[:controller]]
    return :absent unless controller_info && controller_info['patrol_read']

    ssd_value = controller_info['patrol_read']['PR on SSD']
    return 'on' if ssd_value == true
    return 'off' if ssd_value == false
    
    :absent
  rescue StandardError => e
    Puppet.warning("Failed to get patrol read includessds: #{e.message}")
    :absent
  end

  def includessds=(value)
    execute_command("set patrolread includessds=#{value}")
  end

  def uncfgareas
    output = execute_command('show patrolRead', use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == 'PR on EPD' }
    return :absent unless prop
    
    value = prop['Value']
    return 'on' if value =~ /Enabled/i
    return 'off' if value =~ /Disabled/i
    
    :absent
  rescue Puppet::ExecutionFailure => e
    # Some controllers don't support this setting
    Puppet.debug("Failed to get uncfgareas setting: #{e.message}")
    :absent
  end

  def uncfgareas=(value)
    execute_command("set patrolread uncfgareas=#{value}")
  end

  private

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
end
