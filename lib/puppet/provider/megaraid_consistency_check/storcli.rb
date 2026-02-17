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
    output = execute_command('show ccrate')
    match = output.match(/CC Rate.*?(\d+)%/)
    match ? match[1] : :absent
  rescue Puppet::ExecutionFailure => e
    Puppet.warning("Failed to get consistency check rate: #{e.message}")
    :absent
  end

  def rate=(value)
    execute_command("set ccrate=#{value}")
  end

  private

  def execute_command(cmd)
    full_cmd = "#{storcli} #{controller_path} #{cmd} nolog"
    Puppet.debug("Executing: #{full_cmd}")
    output = execute(full_cmd.split(' '), failonfail: true, combine: true)
    Puppet.debug("Command output: #{output}")
    output
  end
end
