# @summary Configure all detected MegaRAID controllers with uniform settings
#
# When `configure_settings` is true this class applies identical
# configuration to every detected controller using the
# `storcli::controller`, `storcli::patrolread`,
# `storcli::consistencycheck`, and `storcli::vd` defined types.
#
# For per-controller configuration, set `configure_settings` to false
# and use the defined types directly, or populate the corresponding
# Hiera hashes (`storcli::controllers`, `storcli::patrolreads`,
# `storcli::consistencychecks`, `storcli::vds`).
#
# @param configure_settings
#   Master switch: apply configuration to all detected controllers.
# @param controller_manage_rebuild
#   Whether to manage rebuild settings (autorebuild, rebuildrate).
# @param controller_autorebuild
#   Enable automatic array rebuilds.
# @param controller_rebuildrate
#   Percentage of IO dedicated to rebuilds (0-100).
# @param sync_time_to_controllers
#   Sync controller clocks with the system clock.
# @param controller_use_utc
#   Use UTC for controller clocks (applies when sync_time is true).
# @param controller_time_tolerance
#   Seconds of drift allowed before a time sync is triggered.
# @param controller_perfmode
#   Performance mode (0 = IOPS, higher = low latency).
# @param controller_ncq
#   Enable Native Command Queue.
# @param controller_cacheflushinterval
#   Seconds between cache flushes.
# @param controller_bootwithpinnedcache
#   Continue booting with data stuck in cache.
# @param controller_manage_alarm
#   Whether to manage the alarm setting.
# @param controller_alarm
#   Enable audible alarm.
# @param controller_smartpollinterval
#   Seconds between SMART error polls (0-65535).
# @param controller_patrolread_mode
#   Patrol read mode: 'auto', 'manual', or 'off'.
# @param controller_patrolread_delay
#   Hours between automatic patrol reads.
# @param controller_patrolread_rate
#   Percentage of IO for patrol reads (0-100).
# @param controller_patrolread_includessds
#   Include SSDs in patrol reads.
# @param controller_patrolread_uncfgareas
#   Patrol unconfigured areas.
# @param controller_consistencycheck_mode
#   Consistency check mode: 'off', 'seq', or 'conc'.
# @param controller_consistencycheck_delay
#   Hours between consistency check runs.
# @param controller_consistencycheck_rate
#   Percentage of IO for consistency checks (0-100).
# @param controller_manage_vd_cache
#   Whether to manage VD cache policies.
# @param controller_vd_write_policy
#   Write cache policy for all VDs.
# @param controller_vd_read_policy
#   Read cache policy for all VDs.
# @param controller_vd_io_policy
#   IO policy for all VDs.
# @param controller_vd_disk_cache
#   Disk cache setting for all VDs.
#
class storcli::configure (
  # lint:ignore:parameter_types
  $configure_settings                = $storcli::configure_settings,
  $controller_manage_rebuild         = $storcli::controller_manage_rebuild,
  $controller_autorebuild            = $storcli::controller_autorebuild,
  $controller_rebuildrate            = $storcli::controller_rebuildrate,
  $sync_time_to_controllers          = $storcli::sync_time_to_controllers,
  $controller_use_utc                = $storcli::controller_use_utc,
  $controller_time_tolerance         = $storcli::controller_time_tolerance,
  $controller_perfmode               = $storcli::controller_perfmode,
  $controller_ncq                    = $storcli::controller_ncq,
  $controller_cacheflushinterval     = $storcli::controller_cacheflushinterval,
  $controller_bootwithpinnedcache    = $storcli::controller_bootwithpinnedcache,
  $controller_manage_alarm           = $storcli::controller_manage_alarm,
  $controller_alarm                  = $storcli::controller_alarm,
  $controller_smartpollinterval      = $storcli::controller_smartpollinterval,
  $controller_patrolread_mode        = $storcli::controller_patrolread_mode,
  $controller_patrolread_delay       = $storcli::controller_patrolread_delay,
  $controller_patrolread_rate        = $storcli::controller_patrolread_rate,
  $controller_patrolread_includessds = $storcli::controller_patrolread_includessds,
  $controller_patrolread_uncfgareas  = $storcli::controller_patrolread_uncfgareas,
  $controller_consistencycheck_mode  = $storcli::controller_consistencycheck_mode,
  $controller_consistencycheck_delay = $storcli::controller_consistencycheck_delay,
  $controller_consistencycheck_rate  = $storcli::controller_consistencycheck_rate,
  $controller_manage_vd_cache        = $storcli::controller_manage_vd_cache,
  $controller_vd_write_policy        = $storcli::controller_vd_write_policy,
  $controller_vd_read_policy         = $storcli::controller_vd_read_policy,
  $controller_vd_io_policy           = $storcli::controller_vd_io_policy,
  $controller_vd_disk_cache          = $storcli::controller_vd_disk_cache,
  # lint:endignore
) inherits storcli {
  if $configure_settings {
    $_controllers = pick($facts.dig('storcli', 'controllers'), {})

    if !$_controllers.empty {
      $_controllers.each |$x, $_ctrl_data| {
        $_storcli_tool = $_ctrl_data['storcli_tool']
        $_autorebuild    = $controller_manage_rebuild ? { true => $controller_autorebuild, default => undef }
        $_rebuildrate    = $controller_manage_rebuild ? { true => $controller_rebuildrate, default => undef }
        $_sync_time      = $sync_time_to_controllers ? { true => true, default => undef }
        $_alarm          = $controller_manage_alarm ? { true => $controller_alarm, default => undef }

        storcli::controller { "controller_${x}":
          controller          => Integer($x),
          storcli_cmd         => $_storcli_tool,
          autorebuild         => $_autorebuild,
          rebuildrate         => $_rebuildrate,
          sync_time           => $_sync_time,
          use_utc             => $controller_use_utc,
          time_tolerance      => $controller_time_tolerance,
          perfmode            => $controller_perfmode,
          ncq                 => $controller_ncq,
          cacheflushinterval  => $controller_cacheflushinterval,
          bootwithpinnedcache => $controller_bootwithpinnedcache,
          alarm               => $_alarm,
          smartpollinterval   => $controller_smartpollinterval,
        }

        storcli::patrolread { "controller_${x}":
          controller  => Integer($x),
          storcli_cmd => $_storcli_tool,
          mode        => $controller_patrolread_mode,
          delay       => $controller_patrolread_delay,
          rate        => $controller_patrolread_rate,
          includessds => $controller_patrolread_includessds,
          uncfgareas  => $controller_patrolread_uncfgareas,
        }

        storcli::consistencycheck { "controller_${x}":
          controller  => Integer($x),
          storcli_cmd => $_storcli_tool,
          mode        => $controller_consistencycheck_mode,
          delay       => $controller_consistencycheck_delay,
          rate        => $controller_consistencycheck_rate,
        }

        if $controller_manage_vd_cache {
          storcli::vd { "controller_${x}":
            controller   => Integer($x),
            virtual_disk => 'all',
            storcli_cmd  => $_storcli_tool,
            write_policy => $controller_vd_write_policy,
            read_policy  => $controller_vd_read_policy,
            io_policy    => $controller_vd_io_policy,
            disk_cache   => $controller_vd_disk_cache,
          }
        }
      }
    }
  }
}
