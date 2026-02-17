# storcli
#
# Main class, include all other classes.
#
# @param package_manage
#   Whether to manage the storcli package. Default value: value of megaraid['present?'].
#
# @param package_name
#   Specifies the storcli package to manage. Default value: ['storcli'].
#
# @param package_ensure
#   Whether to install the storcli package, and what version to install. Values: 'present', 'latest', or a specific version number.
#   Default value: 'present'.
#
# @param link_storcli_to
#   The official package puts the binary into /opt/MegaRAID/storcli which isn't usually in `$PATH`.
#   This module will put a link into another location so the binary is easily found.
#   Default value: /usr/local/sbin
#
# @param configure_settings
#   Should this class be able to enforce configuration settings on the controllers?
#   This is the master kill switch for all configuration management.
#   Default value: true
#
# @param sync_time_to_controllers
#   Should controller clock be synced with the system clock?
#   Default value: true
#
# @param controller_use_utc
#   Should controller clock use UTC?
#   Default value: true
#
# @param controller_defaults
#   Hash of default settings to apply to ALL controllers.
#   Only settings specified in this hash will be managed.
#   Valid keys: autorebuild, rebuildrate, perfmode, ncq, cacheflushinterval,
#               bootwithpinnedcache, alarm, smartpollinterval, patrolread_mode,
#               patrolread_delay, patrolread_rate, patrolread_includessds,
#               patrolread_uncfgareas, consistencycheck_mode, consistencycheck_delay,
#               consistencycheck_rate
#   Default value: {}
#
# @param controller_overrides
#   Hash of per-controller settings that override the defaults.
#   Keys are controller IDs (integers), values are hashes of settings.
#   Example: { 1 => { alarm => false, rebuildrate => 30 } }
#   Default value: {}
#
# @param vd_defaults
#   Hash of default settings to apply to ALL virtual drives.
#   Only settings specified in this hash will be managed.
#   Valid keys: wrcache (wt|wb|awb), rdcache (ra|nora), iopolicy (direct|cached),
#               pdcache (on|off|default)
#   Default value: {}
#
# @param vd_overrides
#   Hash of per-VD settings that override the defaults.
#   Keys are in format "controller_id/vd_id" (e.g., "0/0", "1/2")
#   Values are hashes of settings.
#   Example: { '0/0' => { wrcache => 'wb' } }
#   Default value: {}
#
class storcli (
  # Hiera can convert facts to strings, but we really want a bool
  # https://tickets.puppetlabs.com/browse/PUP-10259
  Variant[Boolean, Enum['true', 'false']] $package_manage,
  Array[String]        $package_name,
  String               $package_ensure,
  Stdlib::Absolutepath $link_storcli_to,
  Boolean              $configure_settings,
  Boolean              $sync_time_to_controllers,
  Boolean              $controller_use_utc,
  Hash                 $controller_defaults,
  Hash                 $controller_overrides,
  Hash                 $vd_defaults,
  Hash                 $vd_overrides,
) {
  contain storcli::install
  contain storcli::configure

  Class['storcli::install'] -> Class['storcli::configure']
}
