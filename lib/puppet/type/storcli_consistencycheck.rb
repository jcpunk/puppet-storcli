# frozen_string_literal: true

Puppet::Type.newtype(:storcli_consistencycheck) do
  @doc = <<-DOC
    @summary
      Manages consistency check settings on a single MegaRAID / Dell PERC controller.

    Uses storcli/perccli JSON output for reliable idempotent management.

    @example Enable concurrent consistency checks on controller 0
      storcli_consistencycheck { '/c0':
        controller => 0,
        mode       => 'conc',
        delay      => 672,
        rate       => 30,
      }
  DOC

  newparam(:name, namevar: true) do
    desc 'Resource title.'
  end

  newparam(:controller) do
    desc 'Integer controller ID (e.g. 0).'
    validate do |value|
      raise Puppet::Error, 'controller must be a non-negative integer' unless value.to_s =~ %r{^\d+$}
    end
    munge { |v| v.to_i }
  end

  newparam(:storcli_cmd) do
    desc 'Path to the storcli or perccli binary.'
    defaultto '/usr/local/sbin/storcli'

    validate do |value|
      raise Puppet::Error, 'storcli_cmd must be an absolute path' unless value.start_with?('/')
    end
  end

  newproperty(:mode) do
    desc "Consistency check mode: 'off', 'seq' (sequential), or 'conc' (concurrent)."
    newvalues(:off, :seq, :conc)
  end

  newproperty(:delay) do
    desc 'Hours between consistency check runs.'
    validate do |value|
      raise Puppet::Error, 'delay must be a non-negative integer' unless value.to_s =~ %r{^\d+$}
    end
    munge { |v| v.to_i }

    def insync?(is)
      return true if @resource[:mode] == :off

      is.to_i == should.to_i
    end
  end

  newproperty(:rate) do
    desc 'Percentage of IO to dedicate to consistency checks (0-100).'
    validate do |value|
      v = value.to_i
      raise Puppet::Error, 'rate must be between 0 and 100' unless v >= 0 && v <= 100
    end
    munge { |v| v.to_i }

    def insync?(is)
      return true if @resource[:mode] == :off

      is.to_i == should.to_i
    end
  end

  validate do
    raise Puppet::Error, 'controller is required' unless self[:controller]
    raise Puppet::Error, 'mode is required' unless self[:mode]
  end

  autorequire(:package) do
    ['storcli']
  end
end
