# MegaRAID Controller Settings Reference

This document provides a comprehensive reference of all configurable settings available for MegaRAID controllers through the puppet-storcli module.

## Table of Contents

- [Currently Supported Settings](#currently-supported-settings)
- [Additional Available Settings](#additional-available-settings)
- [Controller Settings Fact](#controller-settings-fact)
- [Unsupported Features](#unsupported-features)
- [Usage Examples](#usage-examples)

## Currently Supported Settings

The module currently supports managing these controller settings:

### Boolean Settings (on/off)

| Setting | Description | Default | storcli Command |
|---------|-------------|---------|-----------------|
| **autorebuild** | Automatically rebuild failed drives when replaced | `true` | `set autorebuild=on\|off` |
| **copyback** | Copy data back from hot spare to original drive | Not set | `set copyback=on\|off` |
| **jbod** | Enable JBOD mode (use with caution) | Not set | `set jbod=on\|off` |
| **ncq** | Native Command Queuing | `true` | `set ncq=on\|off` |
| **bootwithpinnedcache** | Boot with pinned cache | `false` | `set bootwithpinnedcache=on\|off` |
| **alarm** | Enable controller alarm/buzzer | `true` | `set alarm=on\|off` |

### Numeric Settings

| Setting | Description | Default | Range | storcli Command |
|---------|-------------|---------|-------|-----------------|
| **rebuildrate** | Rebuild rate percentage | `60` | 0-100 | `set rebuildrate=N` |
| **perfmode** | Performance mode | `0` | 0-6 | `set perfmode=N` |
| **cacheflushinterval** | Cache flush interval in seconds | `4` | 1-255 | `set cacheflushint=N` |
| **smartpollinterval** | SMART poll interval in seconds | `60` | varies | `set smartpollinterval=N` |

### Special Settings

| Setting | Description | Values | storcli Command |
|---------|-------------|--------|-----------------|
| **patrolread_mode** | Patrol read mode | auto/manual/off | See patrol read docs |
| **patrolread_delay** | PR delay in hours | Default: 336 | See patrol read docs |
| **patrolread_rate** | PR rate percentage | Default: 30 | See patrol read docs |
| **consistencycheck_mode** | CC mode | off/seq/conc | See CC docs |
| **consistencycheck_delay** | CC delay in hours | Default: 672 | See CC docs |
| **consistencycheck_rate** | CC rate percentage | Default: 30 | See CC docs |

## Additional Available Settings

These settings are available in storcli but not yet implemented in the module. They can be added in future versions based on user needs:

| Setting | Description | Type | storcli Command |
|---------|-------------|------|-----------------|
| **loadbalancemode** | Load balance mode | auto/none | `set loadbalancemode=auto\|none` |
| **abortcconerror** | Abort consistency check on error | on/off | `set abortcconerror=on\|off` |
| **maintainpdflg** | Maintain PD fail history | on/off | `set maintainpdflg=on\|off` |
| **restorehotspare** | Restore hot spare on insertion | on/off | `set restorehotspare=on\|off` |
| **enclpd** | Enclosure Power Down | on/off | `set enclpd=on\|off` |
| **coercion** | Coercion mode | 128MB/1GB/none | `set coercion=N` |
| **bgirate** | Background initialization rate | 0-100 | `set bgirate=N` |
| **spindownunconfigured** | Spin down unconfigured drives | on/off | `set spindownunconfigured=on\|off` |
| **spinupdrives** | Number of drives to spin up | numeric | `set spinupdrives=N` |
| **spinupdelay** | Spin up delay in seconds | numeric | `set spinupdelay=N` |

If you need any of these settings, please open an issue or submit a pull request!

## Controller Settings Fact

Starting with version 2.1.0, the module collects all controller settings as facts. This allows you to:

1. **Query current settings** via PuppetDB
2. **Track configuration drift** across your infrastructure
3. **Make informed decisions** based on current state
4. **Identify unsupported features** on specific controllers

### Fact Structure

```yaml
facts:
  megaraid:
    controllers:
      '0':
        controller_settings:
          Auto Rebuild: 'On'
          Copy Back: 'Off'
          JBOD: 'Un-supported'          # Feature not available
          NCQ Status: 'Enabled'
          Boot With Pinned Cache: 'Off'
          Alarm: 'On'
          Load Balance Mode: 'Auto'
          Rebuild Rate: 60
          Performance Mode: 0
          Cache Flush Interval: 4
          SMART Poll Interval: 60
          # Additional settings collected:
          Abort CC on Error: 'Off'
          Maintain PD Fail History: 'On'
          Restore Hot Spare on Insertion: 'On'
          Spin Down Unconfigured Drives: 'Off'
          Coercion Mode: '128MB'
          BGI Rate: 30
          Spin Up Drive Count: 2
          Spin Up Delay: 2
```

### Fact Collection

The facter:
- Runs `storcli /cX show all J nolog` for each controller
- Parses the JSON output for all settings
- Returns "Un-supported" for features not available on that controller model
- Caches results for performance

## Unsupported Features

Not all controllers support all features. The module handles this gracefully:

### "Un-supported" Sentinel Value

When a controller doesn't support a feature, the fact will show:

```yaml
JBOD: 'Un-supported'
```

This indicates:
- The controller hardware doesn't support this feature
- The firmware version doesn't include this feature
- The feature isn't available in HBA mode

### Common Unsupported Features

| Feature | Common Reason |
|---------|---------------|
| JBOD | Not supported in RAID mode on some controllers |
| NCQ | Older firmware versions |
| Load Balance Mode | HBA-mode controllers |
| Spin Down | Consumer-grade controllers |

### PuppetDB Queries

Find controllers that don't support JBOD:

```bash
puppet query 'inventory[certname] {
  facts.megaraid.controllers.*.controller_settings."JBOD" = "Un-supported"
}'
```

Find controllers with JBOD enabled:

```bash
puppet query 'inventory[certname] {
  facts.megaraid.controllers.*.controller_settings."JBOD" = "On"
}'
```

## Usage Examples

### Basic Configuration

Enable copyback on all controllers:

```yaml
storcli::controller_defaults:
  copyback: true
```

### Per-Controller Override

Enable JBOD on controller 1 only:

```yaml
storcli::controller_defaults:
  jbod: false

storcli::controller_overrides:
  1:
    jbod: true
```

### Pick-and-Choose Settings

Only manage specific settings:

```yaml
storcli::controller_defaults:
  autorebuild: true
  copyback: true
  alarm: false
  # All other settings remain at their current values
```

### Query Current Settings

Using PuppetDB:

```bash
# Get all controller settings
puppet query 'inventory[certname] {
  facts.megaraid.number_of_controllers > 0
} | extract certname, facts.megaraid.controllers.*.controller_settings'

# Find specific setting value
puppet query 'inventory[certname] {
  facts.megaraid.controllers.*.controller_settings."Copy Back" = "On"
}'

# Group by setting value
puppet query 'facts {
  name = "megaraid"
} | extract value.controllers.*.controller_settings."Auto Rebuild" | unique()'
```

### Puppet Code Examples

Check if copyback is supported before enabling:

```puppet
if $facts['megaraid']['controllers']['0']['controller_settings']['Copy Back'] != 'Un-supported' {
  class { 'storcli':
    controller_defaults => {
      copyback => true,
    },
  }
}
```

Alert if JBOD is enabled (security concern):

```puppet
if $facts['megaraid']['controllers']['0']['controller_settings']['JBOD'] == 'On' {
  notify { 'WARNING: JBOD mode is enabled!':
    loglevel => 'warning',
  }
}
```

## Configuration Best Practices

### 1. Check Support First

Before enabling a feature, verify it's supported:

```yaml
# Good: Check via PuppetDB first
# Then set via Hiera only for supported controllers
```

### 2. Use Defaults with Overrides

```yaml
# Set safe defaults for all
storcli::controller_defaults:
  autorebuild: true
  alarm: true

# Override for specific needs
storcli::controller_overrides:
  1:
    alarm: false  # Silent controller in datacenter
```

### 3. Monitor Configuration Drift

Use PuppetDB to track unexpected changes:

```bash
# Weekly check for JBOD being enabled
puppet query 'inventory[certname] {
  facts.megaraid.controllers.*.controller_settings."JBOD" = "On"
}'
```

### 4. Document Your Choices

```yaml
storcli::controller_defaults:
  copyback: true        # Enable to recover original drive after replacement
  jbod: false           # Disabled for security (RAID mode only)
  autorebuild: true     # Auto-rebuild for faster recovery
  alarm: false          # Disabled - monitoring via monitoring system
```

## Troubleshooting

### Setting Shows "Un-supported"

**Cause:** Controller hardware or firmware doesn't support the feature.

**Solution:** 
- Check controller model documentation
- Update firmware if feature was added in newer version
- Some features are mutually exclusive (e.g., JBOD vs RAID mode)

### Setting Won't Change

**Cause:** Some settings require controller reboot or specific prerequisites.

**Solution:**
- Check storcli output for error messages
- Some settings require other settings to be configured first
- Controller may need to be in specific mode

### Query Returns Empty

**Cause:** Facts haven't been collected yet or storcli isn't installed.

**Solution:**
- Ensure puppet-storcli module is applied
- Verify storcli/perccli is installed
- Run `puppet agent -t` to collect facts
- Check `facter megaraid` output

## References

- [StprCLI User Guide](https://docs.broadcom.com/docs/12355769) - Official storcli documentation
- [PuppetDB Query Tutorial](PUPPETDB_QUERIES.md) - Query examples for this module
- [Migration Guide](MIGRATION.md) - Upgrading from v1.x to v2.x

## Contributing

If you need additional settings supported:

1. Check if the setting exists in storcli documentation
2. Open an issue describing your use case
3. Submit a PR following the existing pattern:
   - Add to provider's `get_current_value()` and `set_value()`
   - Add to manifest's controller configuration
   - Add tests
   - Update documentation
