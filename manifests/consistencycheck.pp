# @summary Manage MegaRAID consistency check settings
#
# Configures consistency check scheduling on one or all MegaRAID/PERC
# controllers.  The `mode` parameter is required and determines which
# sub-settings apply.
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
  # lint:ignore:check_unsafe_interpolations lint:ignore:140chars
  if $storcli_cmd {
    $_controller_ids = $controller ? {
      'all'   => pick($facts.dig('storcli', 'controllers'), {}).keys,
      default => [String($controller)],
    }

    $_controller_ids.each |$_id| {
      $_c = "/c${_id}"

      if $mode == 'off' {
        exec { "${name}: Disable consistency check on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set cc=off nolog",
          unless   => "${storcli_cmd} ${_c} show cc nolog | grep 'CC Operation Mode' | grep Disable",
          onlyif   => "${storcli_cmd} ${_c} show cc nolog | grep 'Status = Success'",
          cwd      => '/tmp',
          provider => 'shell',
        }
      } else {
        exec { "${name}: Enable consistency check mode=${mode} on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set cc=${mode} starttime=\"\$(date -u '+%Y/%m/%d') 23\" nolog",
          unless   => "${storcli_cmd} ${_c} show cc nolog | grep -e 'CC Mode\\|CC Operation Mode' | grep -i ${mode}",
          onlyif   => "${storcli_cmd} ${_c} show cc nolog | grep 'Status = Success'",
          cwd      => '/tmp',
          provider => 'shell',
        }

        if $delay != undef {
          exec { "${name}: Set consistency check delay=${delay} on MegaRAID controller ${_c}":
            command  => "${storcli_cmd} ${_c} set cc delay=${delay} nolog",
            unless   => "${storcli_cmd} ${_c} show cc nolog | grep 'CC Execution Delay' | grep ${delay}",
            onlyif   => "${storcli_cmd} ${_c} show cc nolog | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }

        if $rate != undef {
          exec { "${name}: Set consistency check rate=${rate}% on MegaRAID controller ${_c}":
            command  => "${storcli_cmd} ${_c} set ccrate=${rate} nolog",
            unless   => "${storcli_cmd} ${_c} show ccrate nolog | grep 'CC Rate' | grep '${rate}%'",
            onlyif   => "${storcli_cmd} ${_c} show ccrate nolog | grep 'Status = Success'",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }
      }
    }
  }
  # lint:endignore
}
