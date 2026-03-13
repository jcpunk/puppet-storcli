# @summary Manage MegaRAID patrol read settings
#
# Configures patrol read scheduling on one or all MegaRAID/PERC controllers.
# The `mode` parameter is required and determines which sub-settings apply.
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
  # lint:ignore:check_unsafe_interpolations lint:ignore:140chars
  if $storcli_cmd {
    $_controller_ids = $controller ? {
      'all'   => pick($facts.dig('storcli', 'controllers'), {}).keys,
      default => [String($controller)],
    }

    # All unless/onlyif guards use JSON output (J flag) for reliable matching.
    $_show_success = "grep '\"Status\" *: *\"Success\"'"

    $_controller_ids.each |$_id| {
      $_c = "/c${_id}"

      if $mode == 'off' {
        exec { "${name}: Disable patrolread on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set patrolread=off nolog",
          unless   => "${storcli_cmd} ${_c} show patrolread J nolog | grep '\"Value\"' | grep -i '\"Disable'",
          onlyif   => "${storcli_cmd} ${_c} show patrolread J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      } else {
        exec { "${name}: Enable patrolread mode=${mode} on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set patrolread=on mode=${mode} nolog",
          unless   => "${storcli_cmd} ${_c} show patrolread J nolog | grep '\"Value\"' | grep -i '\"${mode}\"'",
          onlyif   => "${storcli_cmd} ${_c} show patrolread J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }

        if $mode == 'auto' and $delay != undef {
          exec { "${name}: Set patrolread delay=${delay} on MegaRAID controller ${_c}":
            command  => "${storcli_cmd} ${_c} set patrolread delay=${delay} nolog",
            unless   => "${storcli_cmd} ${_c} show patrolread J nolog | grep '\"Value\"' | grep '\"${delay} '",
            onlyif   => "${storcli_cmd} ${_c} show patrolread J nolog | ${_show_success}",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }

        if $rate != undef {
          exec { "${name}: Set patrolread rate=${rate}% on MegaRAID controller ${_c}":
            command  => "${storcli_cmd} ${_c} set prrate=${rate} nolog",
            unless   => "${storcli_cmd} ${_c} show prrate J nolog | grep '\"Value\"' | grep '\"${rate}%\"'",
            onlyif   => "${storcli_cmd} ${_c} show patrolread J nolog | ${_show_success}",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }

        if $includessds != undef {
          $_ssds_val = $includessds ? { true => 'Enabled', default => 'Disabled' }
          $_ssds_lbl = $includessds ? { true => 'Enable', default => 'Disable' }
          exec { "${name}: ${_ssds_lbl} patrolread on SSDs on MegaRAID controller ${_c}":
            command  => "${storcli_cmd} ${_c} set patrolread includessds=${includessds ? { true => 'on', default => 'off' }} nolog",
            unless   => "${storcli_cmd} ${_c} show patrolread J nolog | grep '\"PR on SSD\"' -A1 | grep '\"Value\"' | grep '\"${_ssds_val}\"'",
            onlyif   => "${storcli_cmd} ${_c} show patrolread J nolog | ${_show_success}",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }

        if $uncfgareas != undef {
          $_uncfg_val = $uncfgareas ? { true => 'Enabled', default => 'Disabled' }
          $_uncfg_lbl = $uncfgareas ? { true => 'Enable', default => 'Disable' }
          exec { "${name}: ${_uncfg_lbl} patrolread on unconfigured areas on MegaRAID controller ${_c}":
            command  => "${storcli_cmd} ${_c} set patrolread uncfgareas=${uncfgareas ? { true => 'on', default => 'off' }} nolog",
            unless   => "${storcli_cmd} ${_c} show patrolread J nolog | grep '\"PR on EPD\"' -A1 | grep '\"Value\"' | grep '\"${_uncfg_val}\"'",
            onlyif   => [
              "${storcli_cmd} ${_c} show patrolread J nolog | ${_show_success}",
              "${storcli_cmd} ${_c} show patrolread J nolog | grep '\"PR on EPD\"'",
            ],
            cwd      => '/tmp',
            provider => 'shell',
          }
        }
      }
    }
  }
  # lint:endignore
}
