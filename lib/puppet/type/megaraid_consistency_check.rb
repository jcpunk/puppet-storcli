# frozen_string_literal: true

Puppet::Type.newtype(:megaraid_consistency_check) do
  @doc = 'Manages consistency check settings on a MegaRAID controller'

  ensurable

  newparam(:controller, namevar: true) do
    desc 'The controller ID (integer)'
    
    munge do |value|
      Integer(value)
    end
  end

  newproperty(:mode) do
    desc 'Consistency check mode: off, seq, or conc'

    newvalues(:off, :seq, :conc, 'off', 'seq', 'conc')

    munge do |value|
      value.to_s
    end
  end

  newproperty(:delay) do
    desc 'Consistency check delay in hours'

    munge do |value|
      Integer(value)
    end

    validate do |value|
      raise ArgumentError, 'Delay must be a non-negative integer' unless value.to_i >= 0
    end
  end

  newproperty(:rate) do
    desc 'Consistency check IO percentage (0-100)'

    munge do |value|
      Integer(value)
    end

    validate do |value|
      int_value = value.to_i
      raise ArgumentError, 'Rate must be between 0 and 100' unless int_value >= 0 && int_value <= 100
    end
  end

  autorequire(:package) do
    ['storcli', 'perccli']
  end
end
