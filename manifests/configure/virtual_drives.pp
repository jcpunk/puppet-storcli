# @summary Manage virtual drive settings
#
# @api private
#
class storcli::configure::virtual_drives {
  assert_private()

  if $storcli::configure_settings and $facts['megaraid']['storcli'] {
    $controllers = keys($facts['megaraid']['controllers'])
    
    $controllers.each |$controller_id| {
      $controller_info = $facts['megaraid']['controllers'][$controller_id]
      
      if $controller_info and $controller_info['virtual_drives'] {
        $vds = keys($controller_info['virtual_drives'])

        $vds.each |$vd_id| {
          $vd_key = "${controller_id}/${vd_id}"
          
          # Merge defaults with VD-specific overrides
          $vd_config = $storcli::vd_defaults + ($storcli::vd_overrides[$vd_key] ? {
            undef   => {},
            default => $storcli::vd_overrides[$vd_key],
          })

          # Create resources for each specified VD setting
          if $vd_config['wrcache'] {
            megaraid_vd_setting { "${vd_key}:wrcache":
              controller => $controller_id,
              vd         => $vd_id,
              setting    => 'wrcache',
              value      => $vd_config['wrcache'],
            }
          }

          if $vd_config['rdcache'] {
            megaraid_vd_setting { "${vd_key}:rdcache":
              controller => $controller_id,
              vd         => $vd_id,
              setting    => 'rdcache',
              value      => $vd_config['rdcache'],
            }
          }

          if $vd_config['iopolicy'] {
            megaraid_vd_setting { "${vd_key}:iopolicy":
              controller => $controller_id,
              vd         => $vd_id,
              setting    => 'iopolicy',
              value      => $vd_config['iopolicy'],
            }
          }

          if $vd_config['pdcache'] {
            megaraid_vd_setting { "${vd_key}:pdcache":
              controller => $controller_id,
              vd         => $vd_id,
              setting    => 'pdcache',
              value      => $vd_config['pdcache'],
            }
          }
        }
      }
    }
  }
}
