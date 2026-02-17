# frozen_string_literal: true

Puppet::Type.newtype(:megaraid_patrolread) do
  @doc = 'Manages patrol read settings on a MegaRAID controller'

  ensurable

  newparam(:controller, namevar: true) do
    desc 'The controller ID (integer)'
    
    munge do |value|
      Integer(value)
    end
  end

  newproperty(:mode) do
    desc 'Patrol read mode: auto, manual, or off'

    newvalues(:auto, :manual, :off, 'auto', 'manual', 'off')

    munge do |value|
      value.to_s
    end
  end

  newproperty(:delay) do
    desc 'Patrol read delay in hours (only applicable when mode=auto)'

    munge do |value|
      Integer(value)
    end

    validate do |value|
      raise ArgumentError, 'Delay must be a non-negative integer' unless value.to_i >= 0
    end
  end

  newproperty(:rate) do
    desc 'Patrol read IO percentage (0-100)'

    munge do |value|
      Integer(value)
    end

    validate do |value|
      int_value = value.to_i
      raise ArgumentError, 'Rate must be between 0 and 100' unless int_value >= 0 && int_value <= 100
    end
  end

  newproperty(:includessds) do
    desc 'Include SSDs in patrol read: on or off'

    newvalues(:on, :off, 'on', 'off', true, false)

    munge do |value|
      case value
      when true, 'on', :on
        'on'
      when false, 'off', :off
        'off'
      else
        value.to_s
      end
    end
  end

  newproperty(:uncfgareas) do
    desc 'Patrol read on unconfigured areas: on or off'

    newvalues(:on, :off, 'on', 'off', true, false)

    munge do |value|
      case value
      when true, 'on', :on
        'on'
      when false, 'off', :off
        'off'
      else
        value.to_s
      end
    end
  end

  autorequire(:package) do
    ['storcli', 'perccli']
  end
end
