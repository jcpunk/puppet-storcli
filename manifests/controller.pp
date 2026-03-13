# @summary Manage MegaRAID controller settings
#
# Configures general settings on one or all MegaRAID/PERC controllers.
# Each parameter controls an individual setting.  Set a parameter to
# `undef` to leave that setting unmanaged.
#
# This is a convenience wrapper around the `storcli_controller` native
# type that adds support for `controller => 'all'` and integrates
# with the storcli fact for tool discovery.
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
  Optional[String[1]]              $storcli_cmd         = undef,
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
  $_controllers = pick($facts.dig('storcli', 'controllers'), {})
  $_controller_ids = $controller ? {
    'all'   => $_controllers.keys,
    default => [String($controller)],
  }

  $_controller_ids.each |$_id| {
    # Determine the storcli binary: explicit param, per-controller fact, or skip
    $_cmd = $storcli_cmd ? {
      undef   => $_controllers.dig($_id, 'storcli_tool'),
      default => $storcli_cmd,
    }
    if $_cmd {
      # Build a hash of only the properties the user actually set (non-undef).
      # This lets us pass through exactly what was requested to the native type.
      $_base = {
        'controller'  => Integer($_id),
        'storcli_cmd' => $_cmd,
      }
      $_optional = {
        'autorebuild'         => $autorebuild,
        'rebuildrate'         => $rebuildrate,
        'sync_time'           => $sync_time,
        'use_utc'             => $use_utc,
        'time_tolerance'      => $time_tolerance,
        'perfmode'            => $perfmode,
        'ncq'                 => $ncq,
        'cacheflushinterval'  => $cacheflushinterval,
        'bootwithpinnedcache' => $bootwithpinnedcache,
        'alarm'               => $alarm,
        'smartpollinterval'   => $smartpollinterval,
      }.filter |$_k, $_v| { $_v != undef }

      storcli_controller { "${name}_c${_id}":
        * => $_base + $_optional,
      }
    }
  }
}
