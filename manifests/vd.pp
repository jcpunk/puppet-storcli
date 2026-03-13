# @summary Manage MegaRAID virtual disk cache and IO settings
#
# Configures per-VD cache policies on one or all virtual disks across
# one or all MegaRAID/PERC controllers.
#
# This is a convenience wrapper around the `storcli_vd` native type
# that integrates with the storcli fact for tool discovery.
#
# If a setting cannot be applied (e.g. requesting write-back without a
# BBU), storcli will report the error and Puppet will flag the resource
# as failed.
#
# @example Set write-back on all VDs of all controllers
#   storcli::vd { 'fleet_wb':
#     controller   => 'all',
#     virtual_disk => 'all',
#     write_policy => 'wb',
#   }
#
# @example Configure a specific VD
#   storcli::vd { 'c0v1_settings':
#     controller   => 0,
#     virtual_disk => 1,
#     write_policy => 'awb',
#     read_policy  => 'ra',
#     io_policy    => 'direct',
#     disk_cache   => 'default',
#   }
#
# @example Via Hiera (passed through storcli::vds hash)
#   storcli::vds:
#     'fleet_wb':
#       controller: 'all'
#       virtual_disk: 'all'
#       write_policy: wb
#       read_policy: ra
#
# @param controller
#   Controller ID (integer) or 'all' to target every detected controller.
# @param virtual_disk
#   VD ID (integer) or 'all' to target every VD on the controller(s).
# @param storcli_cmd
#   Path to the storcli/perccli binary.
# @param write_policy
#   Write cache policy: 'wt' (WriteThrough), 'wb' (WriteBack),
#   or 'awb' (AlwaysWriteBack).
# @param read_policy
#   Read cache policy: 'ra' (ReadAhead) or 'nora' (No ReadAhead).
# @param io_policy
#   IO policy: 'direct' or 'cached'.
# @param disk_cache
#   Physical disk cache: 'on', 'off', or 'default'.
#
define storcli::vd (
  Variant[Integer[0], Enum['all']]           $controller,
  Variant[Integer[0], Enum['all']]           $virtual_disk,
  Optional[String[1]]                        $storcli_cmd  = undef,
  Optional[Enum['wt', 'wb', 'awb']]         $write_policy = undef,
  Optional[Enum['ra', 'nora']]              $read_policy  = undef,
  Optional[Enum['direct', 'cached']]        $io_policy    = undef,
  Optional[Enum['on', 'off', 'default']]    $disk_cache   = undef,
) {
  $_controllers = pick($facts.dig('storcli', 'controllers'), {})
  # For VD, derive tool from first matching controller or first available
  $_cmd = $storcli_cmd ? {
    undef   => $controller ? {
      'all'   => $_controllers.values.reduce(undef) |$memo, $c| { if $memo { $memo } else { $c['storcli_tool'] } },
      default => $_controllers.dig(String($controller), 'storcli_tool'),
    },
    default => $storcli_cmd,
  }
  if $_cmd {
    $_base = {
      'controller'   => $controller,
      'virtual_disk' => $virtual_disk,
      'storcli_cmd'  => $_cmd,
    }
    $_optional = {
      'write_policy' => $write_policy,
      'read_policy'  => $read_policy,
      'io_policy'    => $io_policy,
      'disk_cache'   => $disk_cache,
    }.filter |$_k, $_v| { $_v != undef }

    storcli_vd { $name:
      * => $_base + $_optional,
    }
  }
}
