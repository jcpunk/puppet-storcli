# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'storcli')

Puppet::Type.type(:storcli_patrolread).provide(
  :storcli,
  parent: Puppet::Provider::Storcli
) do
  desc 'Manage MegaRAID patrol read settings via storcli/perccli JSON interface'

  def pr_props
    @pr_props ||= show_property('patrolread')
  end

  def mode
    val = lookup_value(pr_props, 'PR Mode')
    return nil if val.nil?

    case val
    when /Auto/i    then :auto
    when /Manual/i  then :manual
    when /Disable/i then :off
    else val.to_s.downcase.to_sym
    end
  end

  def mode=(val)
    if val == :off
      storcli_set('set patrolread=off')
    else
      storcli_set("set patrolread=on mode=#{val}")
    end
    @pr_props = nil # reset cache
  end

  def delay
    val = lookup_value(pr_props, 'PR Execution Delay')
    return nil if val.nil?

    # Value may be "336 hours" or "336"
    val.to_s.gsub(/\s*hours?.*/, '').strip.to_i
  end

  def delay=(val)
    storcli_set("set patrolread delay=#{val}")
  end

  def rate
    # prrate is a separate command
    props = show_property('prrate')
    val = lookup_value(props, 'Patrol Read Rate')
    return nil if val.nil?

    val.to_s.gsub('%', '').strip.to_i
  end

  def rate=(val)
    storcli_set("set prrate=#{val}")
  end

  def includessds
    val = lookup_value(pr_props, 'PR on SSD')
    return nil if val.nil?

    enabled_to_bool(val)
  end

  def includessds=(val)
    storcli_set("set patrolread includessds=#{bool_to_onoff(val)}")
  end

  def uncfgareas
    val = lookup_value(pr_props, 'PR on EPD')
    # Some controllers don't support this at all
    return :absent if val.nil?

    enabled_to_bool(val)
  end

  def uncfgareas=(val)
    storcli_set("set patrolread uncfgareas=#{bool_to_onoff(val)}")
  end
end
