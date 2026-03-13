# frozen_string_literal: true

Puppet::Type.newtype(:storcli_vd) do
  @doc = <<-DOC
    @summary
      Manages virtual disk (VD) settings on MegaRAID / Dell PERC controllers.

    Controls per-VD cache policies and I/O behaviour.  Both `controller` and
    `virtual_disk` accept the string 'all' to target every detected item,
    making it easy to enforce a fleet-wide policy.

    If a setting cannot be applied (e.g. requesting write-back without a BBU),
    storcli itself will report the error and Puppet will flag the resource as
    failed so sysadmins can see it in their reports.

    @example Set write-back cache on all VDs of controller 0
      storcli_vd { 'all_vds_c0':
        controller   => 0,
        virtual_disk => 'all',
        write_policy => 'wb',
      }

    @example Uniform policy across every VD on every controller
      storcli_vd { 'fleet_policy':
        controller   => 'all',
        virtual_disk => 'all',
        write_policy => 'wt',
        read_policy  => 'ra',
        io_policy    => 'direct',
        disk_cache   => 'default',
      }

    @example Target a single VD
      storcli_vd { '/c0/v1':
        controller   => 0,
        virtual_disk => 1,
        write_policy => 'awb',
      }
  DOC

  newparam(:name, namevar: true) do
    desc 'Resource title.'
  end

  newparam(:controller) do
    desc "Integer controller ID (e.g. 0) or 'all' to target every detected controller."
    validate do |value|
      unless value.to_s =~ %r{^\d+$} || value.to_s == 'all'
        raise Puppet::Error, "controller must be a non-negative integer or 'all'"
      end
    end
    munge { |v| v.to_s == 'all' ? 'all' : v.to_i }
  end

  newparam(:virtual_disk) do
    desc "Integer VD ID (e.g. 0) or 'all' to target every VD on the controller(s)."
    validate do |value|
      unless value.to_s =~ %r{^\d+$} || value.to_s == 'all'
        raise Puppet::Error, "virtual_disk must be a non-negative integer or 'all'"
      end
    end
    munge { |v| v.to_s == 'all' ? 'all' : v.to_i }
  end

  newparam(:storcli_cmd) do
    desc 'Path to the storcli or perccli binary.'
    defaultto '/usr/local/sbin/storcli'

    validate do |value|
      raise Puppet::Error, 'storcli_cmd must be an absolute path' unless value.start_with?('/')
    end
  end

  # --- Cache policy properties ---

  newproperty(:write_policy) do
    desc "Write cache policy: 'wt' (WriteThrough), 'wb' (WriteBack), or 'awb' (AlwaysWriteBack)."
    newvalues(:wt, :wb, :awb)
  end

  newproperty(:read_policy) do
    desc "Read cache policy: 'ra' (ReadAhead) or 'nora' (No ReadAhead)."
    newvalues(:ra, :nora)
  end

  newproperty(:io_policy) do
    desc "I/O policy: 'direct' or 'cached'."
    newvalues(:direct, :cached)
  end

  newproperty(:disk_cache) do
    desc "Physical disk cache: 'on', 'off', or 'default' (use disk's built-in setting)."
    newvalues(:on, :off, :default)
  end

  validate do
    raise Puppet::Error, 'controller is required' unless self[:controller]
    raise Puppet::Error, 'virtual_disk is required' unless self[:virtual_disk]
  end

  autorequire(:package) do
    ['storcli']
  end
end
