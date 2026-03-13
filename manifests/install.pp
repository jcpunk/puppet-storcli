# @summary
#   This class handles storcli packages and binary link.
#
# @api private
#
class storcli::install (
  # lint:ignore:parameter_types
  $package_manage  = $storcli::package_manage,
  $package_name    = $storcli::package_name,
  $package_ensure  = $storcli::package_ensure,
  $link_storcli_to = $storcli::link_storcli_to,
  # lint:endignore
) inherits storcli {
  assert_private()

  # https://tickets.puppetlabs.com/browse/PUP-10259
  if Boolean($package_manage) {
    package { $package_name:
      ensure => $package_ensure,
    }

    if $facts['storcli'] and $facts['storcli']['present'] and !$facts['storcli']['controllers'].empty() {
      $storcli_path = $facts['storcli']['controllers'].values()[0]['storcli_tool']
      unless $storcli_path == undef or $storcli_path == $link_storcli_to {
        file { $link_storcli_to:
          ensure => 'link',
          target => $storcli_path,
        }
      }
    }
  }
}
