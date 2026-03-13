# frozen_string_literal: true

Puppet::Type.newtype(:megaraid_vd_setting) do
  @doc = 'Manages virtual drive settings on a MegaRAID controller'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the resource, format: controller_id/vd_id:setting_name or controller_id/all:setting_name'

    validate do |value|
      raise ArgumentError, 'Name must be in format "controller_id/vd_id:setting_name"' unless value =~ %r{^\d+/(?:\d+|all):.+$}
    end
  end

  newparam(:controller) do
    desc 'The controller ID (integer)'
    
    munge do |value|
      Integer(value)
    end
  end

  newparam(:vd) do
    desc 'The virtual drive ID (integer or "all")'

    munge do |value|
      value == 'all' ? 'all' : Integer(value)
    end
  end

  newparam(:setting) do
    desc 'The setting name (wrcache, rdcache, iopolicy, pdcache)'

    validate do |value|
      valid_settings = ['wrcache', 'rdcache', 'iopolicy', 'pdcache']
      raise ArgumentError, "Setting must be one of: #{valid_settings.join(', ')}" unless valid_settings.include?(value)
    end
  end

  newproperty(:value) do
    desc 'The value of the setting'

    validate do |value|
      setting = @resource[:setting]
      case setting
      when 'wrcache'
        valid_values = ['wt', 'wb', 'awb']
        raise ArgumentError, "wrcache must be one of: #{valid_values.join(', ')}" unless valid_values.include?(value)
      when 'rdcache'
        valid_values = ['ra', 'nora']
        raise ArgumentError, "rdcache must be one of: #{valid_values.join(', ')}" unless valid_values.include?(value)
      when 'iopolicy'
        valid_values = ['direct', 'cached']
        raise ArgumentError, "iopolicy must be one of: #{valid_values.join(', ')}" unless valid_values.include?(value)
      when 'pdcache'
        valid_values = ['on', 'off', 'default']
        raise ArgumentError, "pdcache must be one of: #{valid_values.join(', ')}" unless valid_values.include?(value)
      end
    end
  end

  autorequire(:package) do
    ['storcli', 'perccli']
  end

  # Parse controller, vd, and setting from name if not explicitly provided
  def self.title_patterns
    [
      [
        %r{^(\d+)/((?:\d+|all)):(.+)$},
        [
          [:controller],
          [:vd],
          [:setting],
        ],
      ],
    ]
  end
end
