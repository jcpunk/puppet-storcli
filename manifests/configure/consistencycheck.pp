# @summary Manage consistency check settings
#
# @api private
#
class storcli::configure::consistencycheck {
  assert_private()

  if $storcli::configure_settings and $facts['megaraid']['storcli'] {
    $controllers = keys($facts['megaraid']['controllers'])
    
    $controllers.each |$controller_id| {
      # Merge defaults with controller-specific overrides
      $controller_config = $storcli::controller_defaults + ($storcli::controller_overrides[$controller_id] ? {
        undef   => {},
        default => $storcli::controller_overrides[$controller_id],
      })

      # Only create consistency check resource if mode is specified
      if $controller_config['consistencycheck_mode'] {
        $cc_params = {
          'controller' => $controller_id,
          'mode'       => $controller_config['consistencycheck_mode'],
        }

        # Add optional parameters if specified
        $cc_with_rate = $controller_config['consistencycheck_rate'] ? {
          undef   => $cc_params,
          default => $cc_params + { 'rate' => $controller_config['consistencycheck_rate'] },
        }

        $cc_final = $controller_config['consistencycheck_delay'] ? {
          undef   => $cc_with_rate,
          default => $cc_with_rate + { 'delay' => $controller_config['consistencycheck_delay'] },
        }

        megaraid_consistency_check { $controller_id:
          * => $cc_final,
        }
      }
    }
  }
}
