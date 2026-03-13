# frozen_string_literal: true

Puppet::Type.newtype(:megaraid_controller_setting) do
  @doc = 'Manages settings on a MegaRAID controller'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the resource, format: controller_id:setting_name'

    validate do |value|
      raise ArgumentError, 'Name must be in format "controller_id:setting_name"' unless value =~ %r{^\d+:.+$}
    end
  end

  newparam(:controller) do
    desc 'The controller ID (integer)'
    
    munge do |value|
      Integer(value)
    end
  end

  newparam(:setting) do
    desc 'The setting name (e.g., autorebuild, rebuildrate, perfmode, etc.)'
  end

  newproperty(:value) do
    desc 'The value of the setting'
  end

  autorequire(:package) do
    ['storcli', 'perccli']
  end

  # Parse controller and setting from name if not explicitly provided
  def self.title_patterns
    [
      [
        %r{^(\d+):(.+)$},
        [
          [:controller],
          [:setting],
        ],
      ],
    ]
  end
end
