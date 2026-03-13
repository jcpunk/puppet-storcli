# @summary Manage controller-level settings
#
# @api private
#
class storcli::configure::controller {
  assert_private()

  if $storcli::configure_settings and $facts['megaraid']['storcli'] {
    $controllers = keys($facts['megaraid']['controllers'])
    
    $controllers.each |$controller_id| {
      # Merge defaults with controller-specific overrides
      $controller_config = $storcli::controller_defaults + ($storcli::controller_overrides[$controller_id] ? {
        undef   => {},
        default => $storcli::controller_overrides[$controller_id],
      })

      # Create resources only for settings that are specified
      if $controller_config['autorebuild'] =~ Boolean {
        megaraid_controller_setting { "${controller_id}:autorebuild":
          controller => $controller_id,
          setting    => 'autorebuild',
          value      => $controller_config['autorebuild'] ? {
            true    => 'on',
            default => 'off',
          },
        }
      }

      if $controller_config['rebuildrate'] =~ Integer {
        megaraid_controller_setting { "${controller_id}:rebuildrate":
          controller => $controller_id,
          setting    => 'rebuildrate',
          value      => String($controller_config['rebuildrate']),
        }
      }

      if $controller_config['perfmode'] =~ Integer {
        megaraid_controller_setting { "${controller_id}:perfmode":
          controller => $controller_id,
          setting    => 'perfmode',
          value      => String($controller_config['perfmode']),
        }
      }

      if $controller_config['ncq'] =~ Boolean {
        megaraid_controller_setting { "${controller_id}:ncq":
          controller => $controller_id,
          setting    => 'ncq',
          value      => $controller_config['ncq'] ? {
            true    => 'on',
            default => 'off',
          },
        }
      }

      if $controller_config['cacheflushinterval'] =~ Integer {
        megaraid_controller_setting { "${controller_id}:cacheflushinterval":
          controller => $controller_id,
          setting    => 'cacheflushinterval',
          value      => String($controller_config['cacheflushinterval']),
        }
      }

      if $controller_config['bootwithpinnedcache'] =~ Boolean {
        megaraid_controller_setting { "${controller_id}:bootwithpinnedcache":
          controller => $controller_id,
          setting    => 'bootwithpinnedcache',
          value      => $controller_config['bootwithpinnedcache'] ? {
            true    => 'on',
            default => 'off',
          },
        }
      }

      if $controller_config['alarm'] =~ Boolean {
        megaraid_controller_setting { "${controller_id}:alarm":
          controller => $controller_id,
          setting    => 'alarm',
          value      => $controller_config['alarm'] ? {
            true    => 'on',
            default => 'off',
          },
        }
      }

      if $controller_config['smartpollinterval'] =~ Integer {
        megaraid_controller_setting { "${controller_id}:smartpollinterval":
          controller => $controller_id,
          setting    => 'smartpollinterval',
          value      => String($controller_config['smartpollinterval']),
        }
      }

      if $controller_config['copyback'] =~ Boolean {
        megaraid_controller_setting { "${controller_id}:copyback":
          controller => $controller_id,
          setting    => 'copyback',
          value      => $controller_config['copyback'] ? {
            true    => 'on',
            default => 'off',
          },
        }
      }

      if $controller_config['jbod'] =~ Boolean {
        megaraid_controller_setting { "${controller_id}:jbod":
          controller => $controller_id,
          setting    => 'jbod',
          value      => $controller_config['jbod'] ? {
            true    => 'on',
            default => 'off',
          },
        }
      }

      # Handle time synchronization (special case - not in the hash)
      if $storcli::sync_time_to_controllers {
        if $storcli::controller_use_utc {
          exec { "Set time on MegaRAID controller /c${controller_id} to UTC":
            command  => "${facts['megaraid']['storcli']} /c${controller_id} set time=\$(date -u '+%Y%m%d %H:%M:%S') nolog",
            unless   => "${facts['megaraid']['storcli']} /c${controller_id} show time nolog | grep Time | grep \$(date -u '+%Y/%m/%d') | grep \$(date -u '+%H:')",
            onlyif   => "${facts['megaraid']['storcli']} /c${controller_id} show time nolog | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        } else {
          exec { "Set time on MegaRAID controller /c${controller_id} to local time":
            command  => "${facts['megaraid']['storcli']} /c${controller_id} set time=systemtime nolog",
            unless   => "${facts['megaraid']['storcli']} /c${controller_id} show time nolog | grep Time | grep \$(date '+%Y/%m/%d') | grep \$(date '+%H:')",
            onlyif   => "${facts['megaraid']['storcli']} /c${controller_id} show time nolog | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }
      }
    }
  }
}
