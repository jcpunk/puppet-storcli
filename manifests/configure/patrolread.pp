# @summary Manage patrol read settings
#
# @api private
#
class storcli::configure::patrolread {
  assert_private()

  if $storcli::configure_settings and $facts['megaraid']['storcli'] {
    $controllers = keys($facts['megaraid']['controllers'])
    
    $controllers.each |$controller_id| {
      # Merge defaults with controller-specific overrides
      $controller_config = $storcli::controller_defaults + ($storcli::controller_overrides[$controller_id] ? {
        undef   => {},
        default => $storcli::controller_overrides[$controller_id],
      })

      # Only create patrol read resource if mode is specified
      if $controller_config['patrolread_mode'] {
        $pr_params = {
          'controller' => $controller_id,
          'mode'       => $controller_config['patrolread_mode'],
        }

        # Add optional parameters if specified
        $pr_with_rate = $controller_config['patrolread_rate'] ? {
          undef   => $pr_params,
          default => $pr_params + { 'rate' => $controller_config['patrolread_rate'] },
        }

        $pr_with_delay = $controller_config['patrolread_delay'] ? {
          undef   => $pr_with_rate,
          default => $pr_with_rate + { 'delay' => $controller_config['patrolread_delay'] },
        }

        $pr_with_ssds = $controller_config['patrolread_includessds'] =~ Boolean ? {
          true    => $pr_with_delay + { 'includessds' => $controller_config['patrolread_includessds'] },
          default => $pr_with_delay,
        }

        $pr_final = $controller_config['patrolread_uncfgareas'] =~ Boolean ? {
          true    => $pr_with_ssds + { 'uncfgareas' => $controller_config['patrolread_uncfgareas'] },
          default => $pr_with_ssds,
        }

        megaraid_patrolread { $controller_id:
          * => $pr_final,
        }
      }
    }
  }
}
