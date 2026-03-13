# puppet-storcli

Puppet module to generate facts with types and providers to manage LSI MegaRAID controllers.

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

This puppet module generate facts and provides types and providers to manage LSI MegaRAID controllers.

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

- **megaraid** - structured fact
  - **present** - Boolean - `true` when a MegaRAID/MPT3SAS driver is found under `/sys/bus/pci/drivers/`; `false` (only key returned) when no hardware is detected or fact collection fails
  - **number_of_controllers** - Integer - number of MegaRAID controllers found (only present when `present` is `true`)
  - **controllers** - Hash[Controller ID] - per-controller information (only present when `present` is `true`)
    - **product_name** - String - Product name
    - **serial_number** - String - Serial number
    - **fw_package_build** - String - Firmware Package Build
    - **fw_version** - String - Firmware Version
    - **bios_version** - String - Controller BIOS Version
    - **driver_name** - String - Kernel driver name
    - **device_interface** - String - Device interface type
    - **drive_groups_count** - Integer - Number of drive groups
    - **physical_drive_count** - Integer - Number of physical drives
    - **storcli_tool** - String - Path to the `storcli`/`perccli` binary used for this controller
    - **drive_groups** - Hash[Drive Group ID] - drive groups on this controller
      - **virtual_disks** - Hash[Virtual Disk ID] - virtual disks in this drive group
        - **name** - String - storcli path (e.g. `/c0/v0`)
        - **raid_level** - String - RAID type (e.g. `RAID6`, `RAID1`)
        - **state** - String - Virtual disk state (e.g. `Optl`)
        - **size** - String - Virtual disk size
        - **os_drive_name** - String - OS device name (e.g. `/dev/sda`)
        - **properties** - Hash - Virtual disk cache and policy settings
          - **stripe_size** - String - Strip size (e.g. `256 KB`)
          - **span_depth** - Integer - Span depth
          - **number_of_drives_per_span** - Integer - Drives per span
          - **current_write_policy** - String - `WriteBack`, `WriteThrough`, or `AlwaysWriteBack`
          - **current_read_policy** - String - `ReadAhead` or `ReadAheadNone`
          - **io_policy** - String - `Direct` or `Cached`
          - **disk_cache_policy** - String - `default`, `on`, or `off`
          - **encryption** - String - Encryption mode
          - **exposed_to_os** - String - Whether the VD is visible to the OS
          - **unmap_enabled** - String - Whether UNMAP/TRIM is enabled
          - **data_protection** - String - Data protection setting
    - **controller_settings** - Hash - Raw controller property key/value pairs
    - **bbu_info** - Hash - Battery Backup Unit information (absent if no BBU)
      - **state** - String - BBU state
      - **type** - String - BBU model/type
      - **replacement_needed** - Boolean - Whether the battery needs replacing
      - **learn_cycle_active** - Boolean - Whether a learn cycle is in progress
    - **patrol_read** - Hash - Patrol read schedule (absent if unsupported)
      - **mode** - String - Patrol read mode (e.g. `Auto`)
      - **execution_delay** - Integer - Delay between runs in hours
      - **on_ssd** - Boolean - Whether patrol read runs on SSDs
      - **next_start_time** - String - Next scheduled run (`YYYY-MM-DD HH:MM:SS`)
    - **consistency_check** - Hash - Consistency check schedule (absent if unsupported)
      - **operation_mode** - String - CC mode (e.g. `Concurrent`)
      - **execution_delay** - Integer - Delay between runs in hours
      - **next_start_time** - String - Next scheduled run (`YYYY-MM-DD HH:MM:SS`)

The rough structure of the fact is:

```yaml
# When no hardware is detected or fact collection fails:
megaraid:
  present: false

# When hardware is present:
megaraid:
  present: true
  number_of_controllers: 1
  controllers:
    '0':
      product_name: 'MegaRAID 9560-8i 4GB'
      serial_number: 'SV123456789'
      fw_package_build: '24.21.0-0155'
      fw_version: '1.460.01-8433'
      bios_version: '7.11.00.3_4.20.00.0000'
      driver_name: 'megaraid_sas'
      device_interface: 'PCI-E'
      drive_groups_count: 1
      physical_drive_count: 8
      storcli_tool: '/usr/bin/storcli64'
      drive_groups:
        '0':
          virtual_disks:
            '0':
              name: '/c0/v0'
              raid_level: 'RAID6'
              state: 'Optl'
              size: '10.914 TB'
              os_drive_name: '/dev/sda'
              properties:
                stripe_size: '256 KB'
                span_depth: 1
                number_of_drives_per_span: 8
                current_write_policy: 'WriteBack'
                current_read_policy: 'ReadAhead'
                io_policy: 'Direct'
                disk_cache_policy: 'default'
                encryption: 'None'
                exposed_to_os: 'Yes'
                unmap_enabled: 'No'
                data_protection: 'Disabled'
      controller_settings:
        'Memory Correctable Errors': 0
        'Memory Uncorrectable Errors': 0
      bbu_info:
        state: 'Optimal'
        type: 'BBU'
        replacement_needed: false
        learn_cycle_active: false
      patrol_read:
        mode: 'Auto'
        execution_delay: 168
        on_ssd: false
        next_start_time: '2026-03-14 03:00:00'
      consistency_check:
        operation_mode: 'Concurrent'
        execution_delay: 168
        next_start_time: '2026-03-14 03:00:00'
```

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

This module purposefully does not manage `storcli`/`perccli2` as there is no obvious way to reconcile the controller numbers. Each one starts counting from zero.

## Development

Contributions are welcome through pull requests. I will only accept PRs with tests covering the parts of the code you touched.

Before sending the PR, run the tests and regenerate puppet strings references:

```
# pdk validate
# pdk test unit
# pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```
