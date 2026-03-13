# @summary Manage MegaRAID patrol read settings
#
# Configures patrol read scheduling on one or all MegaRAID/PERC controllers.
# The `mode` parameter is required and determines which sub-settings apply.
#
# This is a convenience wrapper around the `storcli_patrolread` native
# type that adds support for `controller => 'all'` and integrates
# with the storcli fact for tool discovery.
#
# @example Enable automatic patrol reads on all controllers
#   storcli::patrolread { 'auto_patrol':
#     controller  => 'all',
#     mode        => 'auto',
#     delay       => 336,
#     rate        => 30,
#     includessds => false,
#     uncfgareas  => false,
#   }
#
# @example Disable patrol reads on a specific controller
#   storcli::patrolread { 'no_patrol_c1':
#     controller => 1,
#     mode       => 'off',
#   }
#
# @example Via Hiera (passed through storcli::patrolreads hash)
#   storcli::patrolreads:
#     'all_patrol':
#       controller: 'all'
#       mode: auto
#       delay: 336
#       rate: 30
#
# @param controller
#   Controller ID (integer) or 'all' to target every detected controller.
# @param storcli_cmd
#   Path to the storcli/perccli binary.
#   Defaults to the binary found by the storcli fact.
# @param mode
#   Patrol read mode: 'auto', 'manual', or 'off'.
# @param delay
#   Hours between automatic patrol reads (only applies when mode is 'auto').
# @param rate
#   Percentage of IO to dedicate to patrol reads (0-100).
# @param includessds
#   Whether to include SSD devices in patrol reads.
# @param uncfgareas
#   Whether to patrol unconfigured areas on drives.
#
define storcli::patrolread (
  Variant[Integer[0], Enum['all']] $controller,
  Enum['auto', 'manual', 'off']    $mode,
  Optional[String[1]]              $storcli_cmd  = $facts.dig('storcli', 'storcli_tool'),
  Optional[Integer[0]]             $delay        = undef,
  Optional[Integer[0, 100]]        $rate         = undef,
  Optional[Boolean]                $includessds  = undef,
  Optional[Boolean]                $uncfgareas   = undef,
) {
  if $storcli_cmd {
    $_controller_ids = $controller ? {
      'all'   => pick($facts.dig('storcli', 'controllers'), {}).keys,
      default => [String($controller)],
    }

    $_controller_ids.each |$_id| {
      $_base = {
        'controller'  => Integer($_id),
        'storcli_cmd' => $storcli_cmd,
        'mode'        => $mode,
      }
      $_optional = {
        'delay'       => $delay,
        'rate'        => $rate,
        'includessds' => $includessds,
        'uncfgareas'  => $uncfgareas,
      }.filter |$_k, $_v| { $_v != undef }

      storcli_patrolread { "${name}_c${_id}":
        * => $_base + $_optional,
      }
    }
  }
}
