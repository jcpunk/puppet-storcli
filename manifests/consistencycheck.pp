# @summary Manage MegaRAID consistency check settings
#
# Configures consistency check scheduling on one or all MegaRAID/PERC
# controllers.  The `mode` parameter is required and determines which
# sub-settings apply.
#
# This is a convenience wrapper around the `storcli_consistencycheck` native
# type that adds support for `controller => 'all'` and integrates
# with the storcli fact for tool discovery.
#
# @example Enable concurrent consistency checks on all controllers
#   storcli::consistencycheck { 'cc_all':
#     controller => 'all',
#     mode       => 'conc',
#     delay      => 672,
#     rate       => 30,
#   }
#
# @example Disable consistency checks on a specific controller
#   storcli::consistencycheck { 'no_cc_c1':
#     controller => 1,
#     mode       => 'off',
#   }
#
# @example Via Hiera (passed through storcli::consistencychecks hash)
#   storcli::consistencychecks:
#     'all_cc':
#       controller: 'all'
#       mode: conc
#       delay: 672
#       rate: 30
#
# @param controller
#   Controller ID (integer) or 'all' to target every detected controller.
# @param storcli_cmd
#   Path to the storcli/perccli binary.
#   Defaults to the binary found by the storcli fact.
# @param mode
#   Consistency check mode: 'off', 'seq' (sequential), or 'conc' (concurrent).
# @param delay
#   Hours between consistency check runs.
# @param rate
#   Percentage of IO to dedicate to consistency checks (0-100).
#
define storcli::consistencycheck (
  Variant[Integer[0], Enum['all']] $controller,
  Enum['off', 'seq', 'conc']       $mode,
  Optional[String[1]]              $storcli_cmd = $facts.dig('storcli', 'storcli_tool'),
  Optional[Integer[0]]             $delay       = undef,
  Optional[Integer[0, 100]]        $rate        = undef,
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
        'delay' => $delay,
        'rate'  => $rate,
      }.filter |$_k, $_v| { $_v != undef }

      storcli_consistencycheck { "${name}_c${_id}":
        * => $_base + $_optional,
      }
    }
  }
}
