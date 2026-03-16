# puppet-storcli

Puppet module to generate facts with native types to manage LSI MegaRAID controllers.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

#### Table of Contents

- [puppet-storcli](#puppet-storcli)
      - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Setup](#setup)
    - [Setup Requirements](#setup-requirements)
  - [Usage](#usage)
    - [Install the package](#install-the-package)
    - [Configuration via Hiera](#configuration-via-hiera)
    - [Controller settings](#controller-settings)
    - [Patrol read scheduling](#patrol-read-scheduling)
    - [Consistency check scheduling](#consistency-check-scheduling)
    - [Virtual disk cache policies](#virtual-disk-cache-policies)
    - [Targeting all controllers](#targeting-all-controllers)
    - [Recommended hardened configuration](#recommended-hardened-configuration)
  - [Reference](#reference)
    - [Facts](#facts)
  - [Limitations](#limitations)
  - [Development](#development)

## Description

This puppet module generates facts and provides native resource types to
manage LSI MegaRAID and Dell PERC RAID controllers.

Four native resource types cover the configurable areas:

| Type | Purpose |
|------|---------|
| `storcli_controller` | General controller settings (rebuild, time, perf, NCQ, cache, alarm, SMART) |
| `storcli_patrolread` | Patrol read scheduling |
| `storcli_consistencycheck` | Consistency check scheduling |
| `storcli_vd` | Virtual disk cache and IO policies |

The `storcli` class handles package installation.  Controller
configuration is done by declaring the native types directly in your
profiles or via Hiera.

## Setup

### Setup Requirements

This module makes use of `storcli`.  If running on a Dell server, the module will look to use `perccli` instead.

The package needs to be available from some repository to be installed.

## Usage

### Install the package

```puppet
include storcli
```

This installs the storcli (or perccli on Dell) package when a
MegaRAID/PERC controller is detected.

### Configuration via Hiera

All four native types can be driven entirely from Hiera (or an ENC)
via the hash parameters on the `storcli` class.  The resources are
only created when `$facts['storcli']['present']` is true, so you can
safely set these hashes in a shared Hiera layer and they will be
silently skipped on nodes without RAID hardware.

```yaml
storcli::controllers:
  '/c0':
    ncq: true
    perfmode: 0
    autorebuild: true
    rebuildrate: 60
    sync_time: true
    use_utc: true
    alarm: true
  '/c1':
    ncq: false
    perfmode: 1

storcli::patrolreads:
  '/c0':
    mode: auto
    delay: 336
    rate: 30
    includessds: false
    uncfgareas: false

storcli::consistencychecks:
  'fleet_cc':
    mode: conc
    delay: 672
    rate: 30

storcli::vds:
  '/c0/v0':
    write_policy: wt
    read_policy: ra
    io_policy: direct
    disk_cache: default
```

Hash keys become resource titles.  When the title matches `/c<ID>` or
`/c<ID>/v<ID>` the controller (and virtual disk) are derived
automatically.  Otherwise, set the `controller` parameter explicitly or
let it default to `'all'`.

### Controller settings

Use `storcli_controller` to manage general controller settings.
Each property is independently managed — leave a property unset to
skip management of that setting.

```puppet
storcli_controller { '/c0':
  ncq                 => true,
  perfmode            => 0,
  autorebuild         => true,
  rebuildrate         => 60,
  cacheflushinterval  => 4,
  bootwithpinnedcache => false,
  alarm               => true,
  smartpollinterval   => 60,
  sync_time           => true,
  use_utc             => true,
  time_tolerance      => 120,
}
```

### Patrol read scheduling

```puppet
storcli_patrolread { '/c0':
  mode        => 'auto',
  delay       => 336,
  rate        => 30,
  includessds => false,
  uncfgareas  => false,
}
```

### Consistency check scheduling

```puppet
storcli_consistencycheck { '/c0':
  mode  => 'conc',
  delay => 672,
  rate  => 30,
}
```

### Virtual disk cache policies

```puppet
storcli_vd { '/c0/v0':
  write_policy => 'wt',
  read_policy  => 'ra',
  io_policy    => 'direct',
  disk_cache   => 'default',
}
```

### Targeting all controllers

Pass a title that doesn't match `/c<ID>` and leave `controller`
defaulting to `'all'`:

```puppet
storcli_controller { 'fleet_settings':
  ncq => true,
}

storcli_patrolread { 'fleet_pr':
  mode => 'auto',
  rate => 30,
}
```

### Recommended hardened configuration

The author's preferred defaults for a well-managed environment.
Adapt to your needs:

```puppet
# Install the package
include storcli

# Controller settings applied to all detected controllers
storcli_controller { 'hardened':
  autorebuild         => true,
  rebuildrate         => 60,
  sync_time           => true,
  use_utc             => true,
  time_tolerance      => 120,
  perfmode            => 0,
  ncq                 => true,
  cacheflushinterval  => 4,
  bootwithpinnedcache => false,
  alarm               => true,
  smartpollinterval   => 60,
}

# Patrol read — automatic, every 14 days, 30% IO
storcli_patrolread { 'hardened':
  mode        => 'auto',
  delay       => 336,
  rate        => 30,
  includessds => false,
  uncfgareas  => false,
}

# Consistency check — concurrent, every 28 days, 30% IO
storcli_consistencycheck { 'hardened':
  mode  => 'conc',
  delay => 672,
  rate  => 30,
}
```

## Reference

Items not covered by puppet strings are provided below.

See [REFERENCE](REFERENCE.md) for all other reference documentation.

### Facts

- **storcli** - structured fact
  - **present** - Boolean - `true` if a MegaRAID/PERC controller is detected (checks `/sys/bus/pci/drivers/megaraid_sas` and `/sys/bus/pci/drivers/mpt3sas`)
  - **storcli_tool** - String - Path to the primary `storcli`/`perccli` binary (absent when `present` is `false`)
  - **number_of_controllers** - Integer - number of controllers found
  - **controllers** - Hash[Controller ID] - per-controller data (absent when `present` is `false`)
    - **product_name** - String - Product name
    - **serial_number** - String - Serial number
    - **fw_package_build** - String - Firmware package build string
    - **fw_version** - String - Firmware version
    - **bios_version** - String - Controller BIOS version
    - **driver_name** - String - Kernel driver name
    - **device_interface** - String - Device interface type (e.g. `PCIE`)
    - **drive_groups_count** - Integer - Number of drive groups
    - **physical_drive_count** - Integer - Number of physical drives
    - **storcli_tool** - String - Path to the `storcli`/`perccli` binary used for this controller
    - **drive_groups** - Hash[Drive Group ID] - virtual disk topology
      - **virtual_disks** - Hash[Virtual Disk ID] - per-VD data
        - **name** - String - storcli path for this VD (e.g. `/c0/v0`)
        - **raid_level** - String - RAID level (e.g. `RAID5`)
        - **state** - String - VD state (e.g. `Optl`)
        - **size** - String - VD size (e.g. `3.637 TB`)
        - **os_drive_name** - String - OS device path (e.g. `/dev/sda`)
        - **properties** - Hash - additional VD properties (absent if unavailable)
          - **stripe_size** - String - Strip/stripe size
          - **span_depth** - Integer - Span depth
          - **number_of_drives_per_span** - Integer - Drives per span
          - **current_write_policy** - String - `AlwaysWriteBack`, `WriteBack`, or `WriteThrough`
          - **current_read_policy** - String - `ReadAhead` or `ReadAheadNone`
          - **io_policy** - String - `Direct` or `Cached`
          - **disk_cache_policy** - String - `default`, `on`, or `off`
          - **is_vd_boot_drive** - String - Whether VD is the OS boot drive
          - **encryption** - String - Encryption status
          - **exposed_to_os** - String - Whether VD is visible to the OS
          - **unmap_enabled** - String - Whether UNMAP/TRIM is enabled
          - **data_protection** - String - Data protection setting
    - **controller_settings** - Hash - raw controller property bag from `show all` (key/value pairs; numeric values coerced to Integer)
    - **bbu_info** - Hash - battery backup unit info (absent if no BBU)
      - **state** - String - BBU state
      - **type** - String - BBU model/type
      - **replacement_needed** - Boolean - whether battery replacement is required
      - **learn_cycle_active** - Boolean - whether a learn cycle is in progress
    - **patrol_read** - Hash - patrol read schedule (absent if controller does not support it)
      - **mode** - String - patrol read mode
      - **execution_delay** - Integer - delay between patrol reads in hours
      - **on_ssd** - Boolean - whether patrol read runs on SSDs
      - **next_start_time** - String - next scheduled run (`YYYY-MM-DD HH:MM:SS`)
    - **consistency_check** - Hash - consistency check schedule (absent if controller does not support it)
      - **operation_mode** - String - consistency check mode
      - **execution_delay** - Integer - delay between checks in hours
      - **next_start_time** - String - next scheduled run (`YYYY-MM-DD HH:MM:SS`)

## Limitations

This module provides a custom fact and native resource types for managing
controller-level settings, patrol read scheduling, consistency check
scheduling, and virtual disk cache policies.

The native types (`storcli_controller`, `storcli_patrolread`,
`storcli_consistencycheck`, `storcli_vd`) can be used standalone without
declaring the `storcli` class.  In that case the package is not managed
and the `Class['storcli::install'] ->` ordering is absent.  Ensure the
storcli/perccli binary is installed before the Puppet run, e.g. in the
same profile.

This module does not provide the `storcli` or `perccli` packages, you must do that yourself.  If the `package` provider can load them, they will be installed automatically.

When Hiera hashes are supplied via the class parameters (`storcli::controllers`,
`storcli::patrolreads`, `storcli::consistencychecks`, `storcli::vds`), the
resources are only created when `$facts['storcli']['present']` is true.
This means you can safely include these hashes in a shared Hiera layer —
nodes without RAID hardware will silently skip them.

Not all controllers support every property.  The module handles some
cases automatically (e.g. the `alarm` property is silently skipped on
controllers that report `ABSENT` alarm hardware).  For properties where
the controller lacks support, storcli itself returns an error and Puppet
reports the resource as failed so the sysadmin can investigate.  This
applies, for example, to attempting to set `io_policy` or `write_policy`
on controllers without a BBU.

Settings applied by the native types will propagate storcli failures
back to Puppet — for example, attempting to enable WriteBack on a
controller without a battery backup unit will cause the Puppet run to
report a failure so the sysadmin can investigate.

Minimum `storcli`/`perccli` versions:

```
PercCli SAS Customization Utility Ver 007.2313.0000.0000 Mar 07, 2023
StorCli SAS Customization Utility Ver 007.2508.0000.0000 Feb 27, 2023
```

Older versions may work, but may not...

This module purposefully does not manage `storcli`/`perccli2` as there is no obvious way to reconcile the controller numbers. Each one starts counting from zero.

## Development

Contributions are welcome through pull requests. I will only accept PRs with tests covering the parts of the code you touched.

Before sending the PR, run the tests and regenerate puppet strings references:

```
# pdk validate
# pdk test unit
# pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```
