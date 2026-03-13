# @summary Make any controller settings active
#
# Orchestrates the configuration of storage controllers by including
# specialized sub-classes for different configuration areas.
#
# This class is now an orchestrator that delegates to private sub-classes
# for managing controller settings, patrol read, consistency checks, and
# virtual drive settings.
#
class storcli::configure inherits storcli {
  contain storcli::configure::controller
  contain storcli::configure::patrolread
  contain storcli::configure::consistencycheck
  contain storcli::configure::virtual_drives
}
