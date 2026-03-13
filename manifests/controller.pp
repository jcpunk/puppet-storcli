# @summary Manage MegaRAID controller settings
#
# Configures general settings on one or all MegaRAID/PERC controllers.
# Each parameter controls an individual setting.  Set a parameter to
# `undef` to leave that setting unmanaged.
#
# @example Apply NCQ to all controllers
#   storcli::controller { 'ncq_everywhere':
#     controller => 'all',
#     ncq        => true,
#   }
#
# @example Configure a specific controller
#   storcli::controller { 'controller_0':
#     controller         => 0,
#     ncq                => true,
#     perfmode           => 0,
#     cacheflushinterval => 4,
#   }
#
# @example Via Hiera (passed through storcli::controllers hash)
#   storcli::controllers:
#     'my_settings':
#       controller: 0
#       ncq: true
#       perfmode: 0
#
# @param controller
#   Controller ID (integer) or 'all' to target every detected controller.
# @param storcli_cmd
#   Path to the storcli/perccli binary.
#   Defaults to the binary found by the storcli fact.
# @param autorebuild
#   Enable or disable automatic array rebuilds.
# @param rebuildrate
#   Percentage of IO to dedicate to rebuilds (0-100).
# @param sync_time
#   Sync controller clock with the system clock.
# @param use_utc
#   Use UTC for the controller clock (only applies when sync_time is true).
# @param time_tolerance
#   Maximum allowed drift in seconds between controller and system clock
#   before a sync is triggered.  Avoids unnecessary writes when the
#   controller is only a few seconds off.
# @param perfmode
#   Performance mode (0 = IOPS, higher values favour low latency).
# @param ncq
#   Enable or disable Native Command Queue.
# @param cacheflushinterval
#   Seconds between cache flushes.
# @param bootwithpinnedcache
#   Continue booting with data stuck in cache.
# @param alarm
#   Enable or disable audible alarm.
# @param smartpollinterval
#   Seconds between SMART error polls (0-65535).
#
define storcli::controller (
  Variant[Integer[0], Enum['all']] $controller,
  Optional[String[1]]              $storcli_cmd         = $facts.dig('storcli', 'storcli_tool'),
  Optional[Boolean]                $autorebuild         = undef,
  Optional[Integer[0, 100]]        $rebuildrate         = undef,
  Optional[Boolean]                $sync_time           = undef,
  Boolean                          $use_utc             = true,
  Integer[0]                       $time_tolerance      = 120,
  Optional[Integer[0]]             $perfmode            = undef,
  Optional[Boolean]                $ncq                 = undef,
  Optional[Integer[1]]             $cacheflushinterval  = undef,
  Optional[Boolean]                $bootwithpinnedcache = undef,
  Optional[Boolean]                $alarm               = undef,
  Optional[Integer[0, 65535]]      $smartpollinterval   = undef,
) {
  # lint:ignore:check_unsafe_interpolations lint:ignore:140chars
  if $storcli_cmd {
    $_controller_ids = $controller ? {
      'all'   => pick($facts.dig('storcli', 'controllers'), {}).keys,
      default => [String($controller)],
    }

    $_controller_ids.each |$_id| {
      $_c = "/c${_id}"

      # All unless/onlyif guards use JSON output (J flag) so we can match
      # the exact JSON "Value" field.  This avoids fragile text-parsing of
      # the plain-text storcli output whose format varies between versions.
      #
      # Pattern:  show <setting> J nolog  →  grep '"Status" *: *"Success"'
      # Unless:   grep '"Value"' | grep '"<expected>"'

      $_show_success = "grep '\"Status\" *: *\"Success\"'"

      if $autorebuild != undef {
        $_autorebuild_val = $autorebuild ? { true => 'ON', default => 'OFF' }
        $_autorebuild_lbl = $autorebuild ? { true => 'Enable', default => 'Disable' }
        exec { "${name}: ${_autorebuild_lbl} autorebuild on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set autorebuild=${autorebuild ? { true => 'on', default => 'off' }} nolog",
          unless   => "${storcli_cmd} ${_c} show autorebuild J nolog | grep '\"Value\"' | grep '\"${_autorebuild_val}\"'",
          onlyif   => "${storcli_cmd} ${_c} show autorebuild J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }

      if $rebuildrate != undef {
        exec { "${name}: Set rebuildrate=${rebuildrate}% on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set rebuildrate=${rebuildrate} nolog",
          unless   => "${storcli_cmd} ${_c} show rebuildrate J nolog | grep '\"Value\"' | grep '\"${rebuildrate}%\"'",
          onlyif   => "${storcli_cmd} ${_c} show rebuildrate J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }

      if $sync_time {
        # The unless check parses the controller clock, converts both to epoch
        # seconds, and skips the sync when the difference is within tolerance.
        $_time_unless_utc   = "ct=\$(${storcli_cmd} ${_c} show time J nolog | grep '\"Controller Time\"' | sed 's/.*: *\"//;s/\".*//' | head -1) && ce=\$(date -u -d \"\$(echo \"\$ct\" | tr '/' '-')\" +%s 2>/dev/null) && se=\$(date -u +%s) && d=\$((se - ce)) && [ \${d#-} -le ${time_tolerance} ]"
        $_time_unless_local = "ct=\$(${storcli_cmd} ${_c} show time J nolog | grep '\"Controller Time\"' | sed 's/.*: *\"//;s/\".*//' | head -1) && ce=\$(date -d \"\$(echo \"\$ct\" | tr '/' '-')\" +%s 2>/dev/null) && se=\$(date +%s) && d=\$((se - ce)) && [ \${d#-} -le ${time_tolerance} ]"

        if $use_utc {
          exec { "${name}: Set time on MegaRAID controller ${_c} to UTC":
            command  => "${storcli_cmd} ${_c} set time=\$(date -u '+%Y%m%d %H:%M:%S') nolog",
            unless   => $_time_unless_utc,
            onlyif   => "${storcli_cmd} ${_c} show time J nolog | ${_show_success}",
            cwd      => '/tmp',
            provider => 'shell',
          }
        } else {
          exec { "${name}: Set time on MegaRAID controller ${_c} to local time":
            command  => "${storcli_cmd} ${_c} set time=systemtime nolog",
            unless   => $_time_unless_local,
            onlyif   => "${storcli_cmd} ${_c} show time J nolog | ${_show_success}",
            cwd      => '/tmp',
            provider => 'shell',
          }
        }
      }

      if $perfmode != undef {
        exec { "${name}: Set perfmode=${perfmode} on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set perfmode=${perfmode} nolog",
          unless   => "${storcli_cmd} ${_c} show perfmode J nolog | grep '\"Value\"' | grep '\"${perfmode}\"'",
          onlyif   => "${storcli_cmd} ${_c} show perfmode J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }

      if $ncq != undef {
        $_ncq_val = $ncq ? { true => 'ON', default => 'OFF' }
        $_ncq_lbl = $ncq ? { true => 'Enable', default => 'Disable' }
        exec { "${name}: ${_ncq_lbl} NCQ on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set ncq=${ncq ? { true => 'on', default => 'off' }} nolog",
          unless   => "${storcli_cmd} ${_c} show ncq J nolog | grep '\"Value\"' | grep '\"${_ncq_val}\"'",
          onlyif   => "${storcli_cmd} ${_c} show ncq J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }

      if $cacheflushinterval != undef {
        exec { "${name}: Set cacheflushinterval=${cacheflushinterval} on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set cacheflushint=${cacheflushinterval} nolog",
          unless   => "${storcli_cmd} ${_c} show cacheflushint J nolog | grep '\"Value\"' | grep '\"${cacheflushinterval} sec\"'",
          onlyif   => "${storcli_cmd} ${_c} show cacheflushint J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }

      if $bootwithpinnedcache != undef {
        $_bwpc_val = $bootwithpinnedcache ? { true => 'ON', default => 'OFF' }
        $_bwpc_lbl = $bootwithpinnedcache ? { true => 'Enable', default => 'Disable' }
        exec { "${name}: ${_bwpc_lbl} bootwithpinnedcache on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set bootwithpinnedcache=${bootwithpinnedcache ? { true => 'on', default => 'off' }} nolog",
          unless   => "${storcli_cmd} ${_c} show bootwithpinnedcache J nolog | grep '\"Value\"' | grep '\"${_bwpc_val}\"'",
          onlyif   => "${storcli_cmd} ${_c} show bootwithpinnedcache J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }

      if $alarm != undef {
        $_alarm_val = $alarm ? { true => 'ON', default => 'OFF' }
        $_alarm_lbl = $alarm ? { true => 'Enable', default => 'Disable' }
        exec { "${name}: ${_alarm_lbl} alarm sound on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set alarm=${alarm ? { true => 'on', default => 'off' }} nolog",
          unless   => [
            "${storcli_cmd} ${_c} show alarm J nolog | grep '\"Value\"' | grep '\"${_alarm_val}\"'",
            "${storcli_cmd} ${_c} show alarm J nolog | grep '\"Value\"' | grep '\"ABSENT\"'",
          ],
          onlyif   => "${storcli_cmd} ${_c} show alarm J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }

      if $smartpollinterval != undef {
        exec { "${name}: Set smartpollinterval=${smartpollinterval} on MegaRAID controller ${_c}":
          command  => "${storcli_cmd} ${_c} set smartpollinterval=${smartpollinterval} nolog",
          unless   => "${storcli_cmd} ${_c} show smartpollinterval J nolog | grep '\"Value\"' | grep '\"${smartpollinterval} sec\"'",
          onlyif   => "${storcli_cmd} ${_c} show smartpollinterval J nolog | ${_show_success}",
          cwd      => '/tmp',
          provider => 'shell',
        }
      }
    }
  }
  # lint:endignore
}
