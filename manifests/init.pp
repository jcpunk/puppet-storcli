# @summary Manage LSI MegaRAID / Dell PERC RAID controllers
#
# Installs the storcli/perccli package and configures detected controllers.
#
# **Simple usage** — apply sensible defaults to every controller:
#
#     include storcli
#
# **Per-controller configuration** — disable the automatic sweep and
# declare defined types via Hiera or native Puppet:
#
#     class { 'storcli':
#       configure_settings => false,
#       controllers        => {
#         'c0' => { controller => 0, ncq => true,  perfmode => 0 },
#         'c1' => { controller => 1, ncq => false, perfmode => 1 },
#       },
#     }
#
# @param package_manage
#   Whether to manage the storcli package.
#   Default: value of storcli fact `present` key.
#
# @param package_name
#   Specifies the storcli package to manage.
#
# @param package_ensure
#   Package ensure value: 'present', 'latest', or a specific version.
#
# @param link_storcli_to
#   The official package often puts the binary into /opt/MegaRAID/storcli
#   which is not usually in `$PATH`.  This parameter creates a symlink so
#   the binary is found automatically.
#
# @param configure_settings
#   Master switch.  When true the module applies every controller_*
#   parameter uniformly to all detected controllers.  Set to false when
#   you need per-controller control and use the Hash parameters or
#   the defined types directly.
#
# @param controller_manage_rebuild
#   Manage rebuild settings (autorebuild and rebuildrate).
# @param controller_autorebuild
#   Enable automatic array rebuilds.
# @param controller_rebuildrate
#   Percentage of IO dedicated to rebuilds (0-100).
#
# @param sync_time_to_controllers
#   Sync controller clocks with the system clock.
# @param controller_use_utc
#   Use UTC for controller clocks (only relevant when sync_time is true).
# @param controller_time_tolerance
#   Seconds of drift allowed before a time sync is triggered.
#
# @param controller_perfmode
#   Performance mode (0 = IOPS priority, higher values favour low latency).
# @param controller_ncq
#   Enable Native Command Queue.
# @param controller_cacheflushinterval
#   Seconds between cache flushes.
# @param controller_bootwithpinnedcache
#   Continue booting with data stuck in cache.
#
# @param controller_manage_alarm
#   Manage the alarm setting.  Set to false when the controller
#   does not support alarm management.
# @param controller_alarm
#   Enable audible alarm.
# @param controller_smartpollinterval
#   Seconds between SMART error polls (0-65535).
#
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
#
# @param controller_consistencycheck_mode
#   Consistency check mode: 'off', 'seq', or 'conc'.
# @param controller_consistencycheck_delay
#   Hours between consistency check runs.
# @param controller_consistencycheck_rate
#   Percentage of IO for consistency checks (0-100).
#
# @param controllers
#   Hash of `storcli::controller` resources to create.
#   Keys are resource titles; values are parameter hashes.
#   Useful for per-controller configuration via Hiera.
#
# @param patrolreads
#   Hash of `storcli::patrolread` resources to create.
#
# @param consistencychecks
#   Hash of `storcli::consistencycheck` resources to create.
#
class storcli (
  # Hiera can convert facts to strings, but we really want a bool
  # https://tickets.puppetlabs.com/browse/PUP-10259
  Variant[Boolean, Enum['true', 'false']] $package_manage,
  Array[String] $package_name,
  String        $package_ensure,
  Stdlib::Absolutepath $link_storcli_to,
  Boolean         $configure_settings,
  Boolean         $controller_manage_rebuild,
  Boolean         $controller_autorebuild,
  Integer[0, 100] $controller_rebuildrate,
  Boolean         $sync_time_to_controllers,
  Boolean         $controller_use_utc,
  Integer[0]      $controller_time_tolerance,
  Integer[0]      $controller_perfmode,
  Boolean         $controller_ncq,
  Integer[1]      $controller_cacheflushinterval,
  Boolean         $controller_bootwithpinnedcache,
  Boolean         $controller_manage_alarm,
  Boolean         $controller_alarm,
  Integer[0, 65535]             $controller_smartpollinterval,
  Enum['auto', 'manual', 'off'] $controller_patrolread_mode,
  Integer[0]                    $controller_patrolread_delay,
  Integer[0, 100]               $controller_patrolread_rate,
  Boolean                       $controller_patrolread_includessds,
  Boolean                       $controller_patrolread_uncfgareas,
  Enum['off', 'seq', 'conc']    $controller_consistencycheck_mode,
  Integer[0]                    $controller_consistencycheck_delay,
  Integer[0, 100]               $controller_consistencycheck_rate,
  Hash                          $controllers       = {},
  Hash                          $patrolreads       = {},
  Hash                          $consistencychecks = {},
) {
  contain storcli::install
  contain storcli::configure

  # Ensure install completes before any controller configuration.
  # Order both the defined type wrappers and the native types.
  Class['storcli::install'] -> Storcli::Controller <| |>
  Class['storcli::install'] -> Storcli::Patrolread <| |>
  Class['storcli::install'] -> Storcli::Consistencycheck <| |>
  Class['storcli::install'] -> Storcli_controller <| |>
  Class['storcli::install'] -> Storcli_patrolread <| |>
  Class['storcli::install'] -> Storcli_consistencycheck <| |>

  # Create defined type resources from Hiera hashes.
  # Use this when configure_settings is false and you need
  # per-controller control.
  $controllers.each |$_name, $_params| {
    storcli::controller { $_name:
      * => $_params,
    }
  }
  $patrolreads.each |$_name, $_params| {
    storcli::patrolread { $_name:
      * => $_params,
    }
  }
  $consistencychecks.each |$_name, $_params| {
    storcli::consistencycheck { $_name:
      * => $_params,
    }
  }
}
