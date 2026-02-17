# frozen_string_literal: true

require 'json'

Puppet::Type.type(:megaraid_consistency_check).provide(:storcli) do
  desc 'Manages MegaRAID consistency check settings via storcli/perccli'

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
    return :absent unless controller_info && controller_info['consistency_check']

    cc_mode = controller_info['consistency_check']['CC Operation Mode'] || controller_info['consistency_check']['CC Mode']
    return 'off' if cc_mode =~ /Disable/i
    return 'seq' if cc_mode =~ /Seq/i
    return 'conc' if cc_mode =~ /Conc/i
    
    :absent
  rescue StandardError => e
    Puppet.warning("Failed to get consistency check mode: #{e.message}")
    :absent
  end

  def mode=(value)
    if value == 'off'
      execute_command('set cc=off')
    else
      # Set start time to today at 23:00 UTC
      execute_command("set cc=#{value} starttime=\"$(date -u '+%Y/%m/%d') 23\"")
    end
  end

  def delay
    facts = Facter.value(:megaraid)
    return :absent unless facts && facts['controllers']
    
    controller_info = facts['controllers'][resource[:controller]]
    return :absent unless controller_info && controller_info['consistency_check']

    delay_value = controller_info['consistency_check']['CC Execution Delay']
    delay_value.is_a?(Integer) ? delay_value.to_s : :absent
  rescue StandardError => e
    Puppet.warning("Failed to get consistency check delay: #{e.message}")
    :absent
  end

  def delay=(value)
    execute_command("set cc delay=#{value}")
  end

  def rate
    output = execute_command('show ccrate', use_json: true)
    data = parse_json_response(output)
    return :absent unless data
    
    properties = data['Controller Properties'] || []
    prop = properties.find { |p| p['Ctrl_Prop'] == 'CC Rate' }
    return :absent unless prop
    
    value = prop['Value']
    match = value.to_s.match(/(\d+)%?/)
    match ? match[1] : :absent
  rescue Puppet::ExecutionFailure => e
    Puppet.warning("Failed to get consistency check rate: #{e.message}")
    :absent
  end

  def rate=(value)
    execute_command("set ccrate=#{value}")
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
