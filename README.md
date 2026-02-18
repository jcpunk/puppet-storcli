# puppet-storcli

Puppet module to generate facts with types and providers to manage MegaRAID/PERC controllers.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

#### Table of Contents

- [puppet-storcli](#puppet-storcli)
      - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Setup](#setup)
    - [Setup Requirements](#setup-requirements)
  - [Usage](#usage)
  - [Reference](#reference)
    - [Facts](#facts)
  - [Limitations](#limitations)
  - [Development](#development)

## Description

This puppet module generate facts and provides types and providers to manage MegaRAID/PERC controllers.

## Setup

### Setup Requirements

This module makes use of `storcli`.  If running on a Dell server, the module will look to use `perccli` instead.

The package needs to be available from some repository to be installed.

## Usage

```puppet
include storcli
```

Optionally, to skip over configuration of the card.

```yaml
storcli::configure_settings: false
```

## Reference

Items not covered by puppet strings are provided below.

See [REFERENCE](REFERENCE.md) for all other reference documentation.

### Facts

- **storcli** - structured fact
  - **present** - Boolean - `true` if a MegaRAID/PERC controller is detected (checks `/sys/bus/pci/drivers/megaraid_sas` and `/sys/bus/pci/drivers/mpt3sas`)
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

For now, this module only provides a custom fact and ways to deal with patrol read and consistency check.

This module does not provide the `storcli` or `perccli` packages, you must do that yourself.  If the `package` provider can load them, they will be installed automatically.

The card configuration has not been tested on systems with multiple MegaRAID cards.  It should work, but it will set all cards to identical values.

Minimum `storcli`/`perccli` versions:

```
PercCli SAS Customization Utility Ver 007.2313.0000.0000 Mar 07, 2023
StorCli SAS Customization Utility Ver 007.2508.0000.0000 Feb 27, 2023
```

Older versions may work, but may not...

This module purposefully does not manage `storcli2`/`perccli2` as there is no obvious way to reconcile the controller numbers. Each one starts counting from zero.

## Development

Contributions are welcome through pull requests. I will only accept PRs with tests covering the parts of the code you touched.

Before sending the PR, run the tests and regenerate puppet strings references:

```
# pdk validate
# pdk test unit
# pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```
