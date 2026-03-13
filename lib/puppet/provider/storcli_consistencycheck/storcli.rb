# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'storcli')

Puppet::Type.type(:storcli_consistencycheck).provide(
  :storcli,
  parent: Puppet::Provider::Storcli
) do
  desc 'Manage MegaRAID consistency check settings via storcli/perccli JSON interface'

  def cc_props
    @cc_props ||= show_property('cc')
  end

  def mode
    val = lookup_value(cc_props, 'CC Operation Mode')
    return nil if val.nil?

    case val
    when /Concurrent/i  then :conc
    when /Sequential/i  then :seq
    when /Disable/i     then :off
    else val.to_s.downcase.to_sym
    end
  end

  def mode=(val)
    if val == :off
      storcli_set('set cc=off')
    else
      time_str = Time.now.utc.strftime('%Y/%m/%d')
      storcli_set("set cc=#{val} starttime=\"#{time_str} 23\"")
    end
    @cc_props = nil # reset cache
  end

  def delay
    val = lookup_value(cc_props, 'CC Execution Delay')
    return nil if val.nil?

    # Value may be "672 hours" or "672"
    val.to_s.gsub(/\s*hours?.*/, '').strip.to_i
  end

  def delay=(val)
    storcli_set("set cc delay=#{val}")
  end

  def rate
    props = show_property('ccrate')
    val = lookup_value(props, 'CC Rate')
    return nil if val.nil?

    val.to_s.gsub('%', '').strip.to_i
  end

  def rate=(val)
    storcli_set("set ccrate=#{val}")
  end
end
