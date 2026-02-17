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

### Basic Usage

```puppet
include storcli
```

### Version 2.0+ Hash-Based Configuration

Version 2.0 introduces a Hash-based configuration approach that allows for more flexible controller management:

```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild         => true,
    rebuildrate         => 60,
    perfmode            => 0,
    ncq                 => true,
    cacheflushinterval  => 4,
    alarm               => true,
    smartpollinterval   => 60,
    patrolread_mode     => 'auto',
    patrolread_delay    => 336,
    patrolread_rate     => 30,
    consistencycheck_mode  => 'conc',
    consistencycheck_delay => 672,
    consistencycheck_rate  => 30,
  },
}
```

### Per-Controller Overrides

You can override settings for specific controllers:

```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild => true,
    rebuildrate => 60,
    alarm       => true,
  },
  controller_overrides => {
    1 => {
      alarm       => false,  # Disable alarm on controller 1
      rebuildrate => 30,     # Use different rebuild rate
    },
  },
}
```

### Virtual Drive Cache Settings (New in 2.0)

Manage virtual drive cache policies:

```puppet
class { 'storcli':
  vd_defaults => {
    wrcache  => 'wt',      # Write-through cache
    rdcache  => 'ra',      # Read-ahead cache
    iopolicy => 'direct',  # Direct I/O
    pdcache  => 'default', # Use disk's default cache setting
  },
  vd_overrides => {
    '0/0' => {             # Controller 0, VD 0
      wrcache => 'wb',     # Write-back cache for this VD
    },
  },
}
```

### Pick-and-Choose Settings

Only specify the settings you want to manage:

```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild => true,
    copyback    => true,  # New in v2.1
    alarm       => false,
  },
  # Only autorebuild, copyback, and alarm will be managed
  # All other settings remain at their current values
}
```

For a complete list of available settings, see [CONTROLLER_SETTINGS.md](CONTROLLER_SETTINGS.md).

### Disable Configuration Management

Optionally, to skip over configuration of the card:

```yaml
storcli::configure_settings: false
```

### Migration from v1.x

If you're upgrading from version 1.x, see [MIGRATION.md](MIGRATION.md) for detailed migration instructions.

## Documentation

- **[CONTROLLER_SETTINGS.md](CONTROLLER_SETTINGS.md)** - Complete reference of all controller settings, including supported and unsupported features
- **[MIGRATION.md](MIGRATION.md)** - Migration guide from v1.x to v2.x
- **[PUPPETDB_QUERIES.md](PUPPETDB_QUERIES.md)** - PuppetDB query examples for inventory and tracking
- **[FIXTURE_COLLECTION_GUIDE.md](FIXTURE_COLLECTION_GUIDE.md)** - Guide for collecting test fixtures

## Reference

Items not covered by puppet strings are provided below.

See [REFERENCE](REFERENCE.md) for all other reference documentation.

### Facts

- **megaraid** - structured fact
  - **present?** - Boolean - check if `/sys/bus/pci/drivers/megaraid_sas` is present?
  - **storcli** - String - location of `storcli`/`perccli` application.
  - **number_of_controllers** - Integer - number of megaraid controllers found
  - **controllers** - Hash[Controller number] - structured fact of megaraid controller informations
    - **product_name** - String - Product name
    - **serial_number** - String - Serial number
    - **fw_package_build** - String - Firmware Package Build
    - **fw_version** - String - Firmware Version
    - **bios_version** - String - Controller BIOS Version
    - **virtual_drives** - Hash - Drive settings per virtual drive
      - **Name** - String - Name of Virtual Disk
      - **Type** - String - Type of RAID
      - **State** - String - State of Virtual Disk
      - **Strip Size** - String - Strip Size of Virtual Disk
      - **Write Cache** - String - Write Cache Mode of Virtual Disk
      - **Read Cache** - String - Read Cache Mode of Virtual Disk
      - **IO Policy** - String - IO Policy of Virtual Disk
      - **Physical Drive Cache** - String - Physical Drive Cache Mode of Virtual Disk
      - **Encryption** - String - Encryption Mode of Virtual Disk
    - **patrol_read** - Hash - Patrol read information
      - **PR Mode** - String - Mode
      - **PR Execution Delay** - Integer - Execution delay in hours
      - **PR iterations completed** - Integer - How many times patrol read ran?
      - **PR Next Start time** - DateTime - Next time patrol read will run
      - **PR on SSD** - Boolean - Run on SSDs?
      - **PR Current State** - String - Is it running or stopped?
      - **PR Excluded VDs** - String - VDs that will not run patrol read
      - **PR MaxConcurrentPd** - Integer - Maximum number of concurrent PDs
    - **consistency_check** - Hash - Consistency check information
      - **CC Operation Mode** - String - Mode
      - **CC Execution Delay** - Integer - Execution delay in hours
      - **CC Next Starttime** - DateTime - Next time patrol read will run
      - **CC Current State** - String - Is it running or stopped?
      - **CC Number of iterations** - Integer - How many times patrol read ran?
      - **CC Number of VD completed** - Integer - Number of VDs completed
      - **CC Excluded VDs** - String - VDs that will not run patrol read
    - **controller_settings** - Hash - Controller configuration settings
      - **Auto Rebuild** - String - Auto rebuild status (On/Off/Un-supported)
      - **Copy Back** - String - Copy back status (On/Off/Un-supported)
      - **JBOD** - String - JBOD mode (On/Off/Un-supported)
      - **NCQ Status** - String - NCQ status (Enabled/Disabled/Un-supported)
      - **Boot With Pinned Cache** - String - Boot with pinned cache (On/Off/Un-supported)
      - **Alarm** - String - Alarm status (On/Off/Un-supported)
      - **Load Balance Mode** - String - Load balance mode (Auto/None/Un-supported)
      - **Rebuild Rate** - Integer - Rebuild rate percentage
      - **Performance Mode** - Integer - Performance mode (0-6)
      - **Cache Flush Interval** - Integer - Cache flush interval in seconds
      - **SMART Poll Interval** - Integer - SMART poll interval in seconds
      - Note: Settings show "Un-supported" if not available on controller

### PuppetDB Queries

If you have PuppetDB set up, you can query for MegaRAID controllers across your infrastructure. See **[PUPPETDB_QUERIES.md](PUPPETDB_QUERIES.md)** for comprehensive examples including:

- Listing all hosts with controllers
- Grouping by controller model
- Finding specific firmware versions
- Identifying cache policy configurations
- Multi-controller system detection

**Quick example:**
```bash
# List all different controller models in your infrastructure
puppet query 'facts { name = "megaraid" } | extract value.controllers.*.product_name | unique()'
```

## Limitations

Version 2.0+ now supports per-controller configuration through the `controller_overrides` parameter, allowing different settings for each controller.

This module does not provide the `storcli` or `perccli` packages, you must do that yourself. If the `package` provider can load them, they will be installed automatically.

Minimum `storcli`/`perccli` versions:

```
PercCli SAS Customization Utility Ver 007.2313.0000.0000 Mar 07, 2023
StorCli SAS Customization Utility Ver 007.2508.0000.0000 Feb 27, 2023
```

Older versions may work, but may not...

## Development

Contributions are welcome through pull requests. I will only accept PRs with tests covering the parts of the code you touched.

### Adding Fixture Data

If you have access to different MegaRAID controllers and want to contribute test fixtures:

1. See **[FIXTURE_SUMMARY.md](FIXTURE_SUMMARY.md)** for a quick start guide
2. See **[FIXTURE_COLLECTION_GUIDE.md](FIXTURE_COLLECTION_GUIDE.md)** for comprehensive documentation
3. Use the automated script: `sudo ./scripts/collect_fixtures.sh`
4. See **[FIXTURE_TEST_TEMPLATE.md](FIXTURE_TEST_TEMPLATE.md)** for adding test cases

Good test coverage requires fixtures from diverse hardware:
- Different controller models (LSI 3108, 9560, Dell PERC, etc.)
- Both storcli and perccli variants
- Multi-controller systems
- Various cache configurations and RAID levels

### Running Tests

Before sending the PR, run the tests and regenerate puppet strings references:

```
# pdk validate
# pdk test unit
# pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```
