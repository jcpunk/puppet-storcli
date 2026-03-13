# MegaRAID Fact Enhancements

This document describes the comprehensive enhancements made to the `megaraid` fact in this PR.

## Overview

This PR enhances the megaraid fact collection to include:
1. **Controller settings** - Configuration state for each controller
2. **BBU/CacheVault health** - Battery backup unit health summary
3. **Virtual drive properties** - Static VD configuration details
4. **Physical drive summary** - Aggregate statistics about drives
5. **Additional controller properties** - Load balance mode, enclosure PD, etc.

All enhancements follow the principle: **Configuration data YES, Monitoring data NO**.

## Implemented Changes

### 1. Controller Settings (`controller_settings`)

Each controller now includes a `controller_settings` hash with configuration state:

```yaml
megaraid:
  controllers:
    '0':
      controller_settings:
        'Auto Rebuild': 'On'
        'Copy Back': 'Off'
        'JBOD': 'Un-supported'  # Sentinel for unsupported features
        'NCQ Status': 'Enabled'
        'Boot With Pinned Cache': 'Off'
        'Alarm': 'On'
        'Load Balance Mode': 'Auto'
        'Rebuild Rate': 60
        'Performance Mode': 0
        'Cache Flush Interval': 4
        'SMART Poll Interval': 60
        'Maintain PD Fail History': 'On'
        'Enclosure PD': 'On'
```

**Why these settings?**
- Configuration-related (not volatile monitoring data)
- Useful for PuppetDB queries to find configuration drift
- Change infrequently (suitable for facts)
- Support "Un-supported" sentinel for features not available on specific hardware

**PuppetDB Query Example:**
```puppet
# Find controllers with JBOD support
inventory[certname] {
  facts.megaraid.controllers.*.controller_settings."JBOD" != "Un-supported"
}

# Find controllers with different rebuild rates
inventory[certname] {
  facts.megaraid.controllers.*.controller_settings."Rebuild Rate" != 60
}
```

### 2. BBU/CacheVault Health (`bbu_info`)

Summary health information for battery backup units:

```yaml
megaraid:
  controllers:
    '0':
      bbu_info:
        state: 'Optimal'
        type: 'BBU'
        charge_percent: 100
        replacement_needed: false
        learn_cycle_active: false
        temperature: '28 C'
```

**Why include this?**
- Critical for RAID availability (without BBU, write cache disabled)
- Configuration-adjacent (affects controller behavior)
- Changes infrequently (replacement is a planned event)
- Useful for capacity planning

**What's excluded?**
- Detailed voltage/current metrics (monitoring data)
- Historical charge cycles (monitoring data)
- Real-time power draw (volatile)

**PuppetDB Query Example:**
```puppet
# Find controllers needing BBU replacement
inventory[certname] {
  facts.megaraid.controllers.*.bbu_info.replacement_needed = true
}

# Find controllers without BBU
inventory[certname] {
  facts.megaraid.controllers.*.bbu_info.type = "Un-supported"
}
```

### 3. Virtual Drive Properties (`virtual_drives.<vd_id>.properties`)

Static configuration properties for each virtual drive:

```yaml
megaraid:
  controllers:
    '0':
      virtual_drives:
        '0':
          name: '/c0/v0'
          raid_level: 'RAID6'
          size: '3.637 TB'
          state: 'Optl'
          properties:
            stripe_size: '256 KB'
            span_depth: 1
            number_of_drives_per_span: 8
            default_cache_policy: 'WriteBack'
            current_cache_policy: 'WriteBack'
            default_write_policy: 'WriteBack'
            current_write_policy: 'WriteBack'
            default_read_policy: 'ReadAheadNone'
            current_read_policy: 'ReadAhead'
            is_vd_boot_drive: 'No'
```

**Why include this?**
- Static configuration (doesn't change unless VD is recreated)
- Important for understanding RAID layout
- Useful for capacity planning and optimization
- Cache policies affect performance and data safety

**What's excluded?**
- Ongoing operations (init, rebuild, migration - volatile)
- Bad blocks count (monitoring data)
- Access policy changes (volatile)

**PuppetDB Query Example:**
```puppet
# Find VDs with WriteThrough cache (safer but slower)
inventory[certname] {
  facts.megaraid.controllers.*.virtual_drives.*.properties.current_cache_policy ~ "WriteThrough"
}

# Find boot drives
inventory[certname] {
  facts.megaraid.controllers.*.virtual_drives.*.properties.is_vd_boot_drive = "Yes"
}
```

### 4. Physical Drive Summary (`physical_drive_summary`)

Aggregate statistics about physical drives (not per-drive details):

```yaml
megaraid:
  controllers:
    '0':
      physical_drive_summary:
        total_drives: 24
        drives_by_state:
          'Onln': 16
          'GHS': 2
          'DHS': 1
          'Offln': 0
          'UGood': 5
        drives_by_type:
          'SAS': 16
          'SATA': 8
        drives_by_media:
          'HDD': 20
          'SSD': 4
        total_capacity: '43.651 TB'
        average_temperature: 32
        drives_over_temperature: 0
        predictive_failures: 0
```

**Why summary instead of per-drive?**
- Avoids huge facts (100 drives × 40 properties = 4000 fields!)
- Provides useful overview without overwhelming detail
- Sufficient for capacity planning and health monitoring
- Per-drive details better suited for monitoring systems

**What's excluded?**
- Per-drive error counters (monitoring data)
- Per-drive serial numbers (too granular)
- Per-drive power-on hours (monitoring data)

**PuppetDB Query Example:**
```puppet
# Find controllers with offline drives
inventory[certname] {
  facts.megaraid.controllers.*.physical_drive_summary.drives_by_state."Offln" > 0
}

# Find controllers with predictive failures
inventory[certname] {
  facts.megaraid.controllers.*.physical_drive_summary.predictive_failures > 0
}
```

## Un-supported Sentinel

Throughout these enhancements, we use `"Un-supported"` as a sentinel value when:
- A feature is not available on the controller hardware
- A component is not present (e.g., no BBU)
- A command fails or returns no data

This allows PuppetDB queries to distinguish between:
- Feature is disabled: `'Off'` or `false`
- Feature doesn't exist: `'Un-supported'`

**Example:**
```yaml
'JBOD': 'Un-supported'  # Controller doesn't support JBOD mode at all
'JBOD': 'Off'           # Controller supports JBOD but it's disabled
```

## Benefits

### 1. Configuration Management
- Track configuration drift across infrastructure
- Identify non-standard configurations
- Plan configuration changes based on current state

### 2. Capacity Planning
- Identify controllers with capacity issues
- Track drive types and media across fleet
- Plan for expansion or replacement

### 3. Health Monitoring Integration
- BBU health status for alerting
- Predictive failure counts
- Temperature trending

### 4. Compliance Auditing
- Verify cache policies meet requirements
- Check hot spare allocation
- Ensure consistent controller settings

### 5. PuppetDB Intelligence
- Query for specific configurations
- Group hosts by controller characteristics
- Generate reports on RAID usage

## Design Principles

### Include in Facts
✅ Configuration-related data
✅ Static or infrequently changing
✅ Useful for PuppetDB queries
✅ Affects system behavior
✅ Capacity planning data

### Exclude from Facts
❌ Volatile data (changes constantly)
❌ Monitoring metrics (better in Prometheus/Nagios)
❌ Too granular (per-drive details)
❌ Historical data (event logs)
❌ Real-time status (current operations)

## Fact Size Impact

**Before enhancements:**
- ~200 lines of YAML per controller
- ~50 KB for typical 2-controller system

**After enhancements:**
- ~350 lines of YAML per controller
- ~85 KB for typical 2-controller system

**Mitigation:**
- Summary statistics instead of per-drive details
- Only static properties, not volatile status
- Reasonable for systems with <10 controllers

## Testing

All enhancements include:
- Unit tests for fact collection
- Fixture-based testing
- PuppetDB query examples
- Documentation updates

## Future Enhancements

Potential additions based on user feedback:
- Enclosure information summary
- Foreign configuration detection
- Hot spare configuration details
- Drive firmware version summary

See `MISSING_FACT_SETTINGS.md` for complete analysis.

## Migration

These enhancements are **backward compatible**:
- Existing fact fields unchanged
- New fields added alongside existing
- Old queries continue to work
- No breaking changes

## Examples

### Complete Controller Fact

```yaml
megaraid:
  storcli: '/opt/MegaRAID/storcli/storcli64'
  present: true
  number_of_controllers: 1
  controllers:
    '0':
      model: 'AVAGO 3108 MegaRAID'
      serial: 'SK83952372'
      firmware: '4.680.00-8290'
      controller_settings:
        'Auto Rebuild': 'On'
        'Copy Back': 'Off'
        'JBOD': 'Un-supported'
        'Load Balance Mode': 'Auto'
        'Rebuild Rate': 60
      bbu_info:
        state: 'Optimal'
        charge_percent: 100
        replacement_needed: false
      physical_drive_summary:
        total_drives: 16
        drives_by_state:
          'Onln': 14
          'GHS': 2
        total_capacity: '21.818 TB'
      virtual_drives:
        '0':
          name: '/c0/v0'
          raid_level: 'RAID6'
          properties:
            stripe_size: '256 KB'
            span_depth: 1
            current_cache_policy: 'WriteBack'
```

## References

- `MISSING_FACT_SETTINGS.md` - Analysis of what to include/exclude
- `UNMANAGED_FEATURES.md` - Features not managed by module
- `PUPPETDB_QUERIES.md` - Query examples for all facts
- `README.md` - Main module documentation

