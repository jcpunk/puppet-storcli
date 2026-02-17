# Missing Fact Settings Analysis

This document analyzes settings and information available through storcli/perccli that are **NOT** currently included in the `megaraid` fact, along with reasoning about whether they should be added.

## Table of Contents

1. [Overview](#overview)
2. [Controller-Level Settings](#controller-level-settings)
3. [Virtual Drive Settings](#virtual-drive-settings)
4. [Physical Drive Information](#physical-drive-information)
5. [BBU/CacheVault Information](#bbucachevault-information)
6. [Enclosure Information](#enclosure-information)
7. [Summary and Recommendations](#summary-and-recommendations)

## Overview

The current `megaraid` fact includes:
- ✅ Basic controller information (model, serial, firmware)
- ✅ Controller settings (rebuild rate, alarm, etc.)
- ✅ Virtual drive basic info (RAID level, size, cache policies)
- ✅ Patrol read settings
- ✅ Consistency check settings
- ✅ Number of controllers

This analysis examines what's **missing** and whether it should be added.

### Decision Criteria

Settings are evaluated based on:
- **Value**: How useful is this information for configuration management?
- **Volatility**: How frequently does it change?
- **Size**: Impact on fact size/performance
- **Risk**: Could it expose sensitive data or cause issues?
- **Use Case**: Is PuppetDB the right place for this data?

## Controller-Level Settings

### Currently Missing from Facts

#### 1. Load Balance Mode ⭐ SHOULD ADD

**What it is:**
- Controls how IO is distributed across paths in multi-path configurations
- Values: `Auto`, `None`
- Command: Visible in `storcli /cX show all J`

**Why it's missing:**
- Not part of initial implementation
- Considered less critical than other settings

**Should we add it?**
**YES** - Recommendation: **Add to `controller_settings`**

**Reasoning:**
- ✅ Useful for multi-path configurations
- ✅ Static (doesn't change frequently)
- ✅ Small data footprint
- ✅ Relevant for configuration management
- ✅ Already available in controller settings query

**Implementation:**
```ruby
# In controller_settings_info method
settings['Load Balance Mode'] = controller_settings['Load Balance Mode']
```

---

#### 2. Enable JBOD / Enclosure PD ⭐ SHOULD ADD

**What it is:**
- `enclpd`: Enables enclosure power/fan detection
- Values: `On`, `Off`, `Un-supported`
- Command: `storcli /cX show all J`

**Why it's missing:**
- Recently identified as useful
- Not part of initial feature set

**Should we add it?**
**YES** - Recommendation: **Add to `controller_settings`**

**Reasoning:**
- ✅ Important for enclosure management
- ✅ Static configuration
- ✅ Helps with environmental monitoring
- ✅ Small data size

---

#### 3. Maintain PD Fail History ⭐ SHOULD ADD

**What it is:**
- `maintainpdflg`: Whether controller maintains drive failure history
- Values: `On`, `Off`
- Command: `storcli /cX show all J`

**Why it's missing:**
- Not prioritized in initial implementation

**Should we add it?**
**YES** - Recommendation: **Add to `controller_settings`**

**Reasoning:**
- ✅ Useful for tracking drive reliability
- ✅ Static setting
- ✅ Helps with predictive maintenance
- ✅ Small footprint

---

#### 4. Restore Hot Spare on Insertion ⚠️ MAYBE ADD

**What it is:**
- `restorehotspare`: Automatically restore hot spare status when drive is reinserted
- Values: `On`, `Off`
- Command: `storcli /cX show all J`

**Why it's missing:**
- Niche use case
- Not all environments use hot spares

**Should we add it?**
**MAYBE** - Recommendation: **Consider for future**

**Reasoning:**
- ⚠️ Useful for hot spare management
- ⚠️ Only relevant if using hot spares
- ✅ Static setting
- ❌ Lower priority than other settings

---

#### 5. Abort CC on Error ⚠️ MAYBE ADD

**What it is:**
- `abortcconerror`: Whether to abort consistency check when error is found
- Values: `On`, `Off`
- Command: `storcli /cX show all J`

**Why it's missing:**
- Niche setting
- Most users leave at default

**Should we add it?**
**MAYBE** - Recommendation: **Low priority**

**Reasoning:**
- ⚠️ Specialized use case
- ✅ Static setting
- ❌ Most users don't modify this
- ❌ Lower value for general use

---

#### 6. Enable Spin Down Unconfigured ❌ SHOULD NOT ADD

**What it is:**
- `enablespindown`: Spin down unconfigured drives to save power
- Values: `On`, `Off`
- Command: `storcli /cX show all J`

**Why it's missing:**
- High risk setting
- Can cause unexpected behavior

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Can cause drives to become unavailable
- ❌ May impact performance unpredictably
- ❌ Risk of drive spin-up delays
- ❌ Better managed manually
- ❌ Too volatile (drives spin up/down frequently)

---

#### 7. Spin Up Delay ❌ SHOULD NOT ADD

**What it is:**
- `spinupdelay`: Delay between drive spin-ups (seconds)
- Values: Numeric (0-255)
- Command: `storcli /cX show all J`

**Why it's missing:**
- Very specialized use case
- Rarely modified

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Rarely used
- ❌ Very specialized
- ❌ Low value for general configuration
- ❌ Better left at defaults

---

#### 8. Coercion Mode ❌ SHOULD NOT ADD

**What it is:**
- How controller handles drives of slightly different sizes
- Values: `128MB`, `1GB`, `None`
- Command: `storcli /cX show all J`

**Why it's missing:**
- Rarely changed
- Advanced/niche setting

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Rarely modified
- ❌ Advanced use case
- ❌ Can cause data loss if changed incorrectly
- ❌ Better managed manually

---

#### 9. Cluster Enable ❌ SHOULD NOT ADD

**What it is:**
- Enables clustering support
- Values: `Enabled`, `Disabled`
- Command: `storcli /cX show all J`

**Why it's missing:**
- Very specialized feature
- Rarely used

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Very specialized
- ❌ Requires specific hardware/software
- ❌ Not applicable to most users
- ❌ Low priority

---

#### 10. Controller Time (Current Time) ❌ SHOULD NOT ADD

**What it is:**
- Current time on controller
- Values: Timestamp
- Command: `storcli /cX show all J`

**Why it's missing:**
- Highly volatile
- Already managed via `sync_time_to_controllers`

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Changes every second (too volatile)
- ❌ No value as a fact
- ❌ Already have time sync management
- ❌ Would cause constant fact changes

---

## Virtual Drive Settings

### Currently Missing from Facts

#### 1. VD Static Properties ⭐ SHOULD ADD

**What it is:**
- Stripe Size (KB)
- Span Depth
- Number of Drives Per Span
- Values: Numeric
- Command: `storcli /cX/vX show all J`

**Why it's missing:**
- Not prioritized in initial implementation
- Focus was on cache policies

**Should we add it?**
**YES** - Recommendation: **Add to VD facts**

**Reasoning:**
- ✅ Static (doesn't change after VD creation)
- ✅ Useful for auditing RAID configuration
- ✅ Helps with performance analysis
- ✅ Small data size
- ✅ Already in JSON output

**Implementation:**
```ruby
vd_data['stripe_size_kb'] = vd_props['Strip Size']
vd_data['span_depth'] = vd_props['Number of Spans']
vd_data['drives_per_span'] = vd_props['Number of Drives Per Span']
```

---

#### 2. Boot Drive Status ⚠️ MAYBE ADD

**What it is:**
- Whether VD is configured as boot drive
- Values: `Primary`, `None`
- Command: `storcli /cX/vX show all J`

**Why it's missing:**
- Niche use case
- Not all systems boot from RAID

**Should we add it?**
**MAYBE** - Recommendation: **Consider for future**

**Reasoning:**
- ⚠️ Useful for boot configuration tracking
- ⚠️ Only relevant for boot drives
- ✅ Static property
- ❌ Lower priority

---

#### 3. VD Name/Label ⚠️ MAYBE ADD

**What it is:**
- User-assigned name for virtual drive
- Values: String (up to 15 characters)
- Command: `storcli /cX/vX show all J`

**Why it's missing:**
- Not commonly used
- Most VDs don't have custom names

**Should we add it?**
**MAYBE** - Recommendation: **Low priority**

**Reasoning:**
- ⚠️ Can be useful for identification
- ⚠️ Most VDs have no name
- ✅ Static (once set)
- ❌ Low usage in practice

---

#### 4. VD Access Policy ❌ SHOULD NOT ADD

**What it is:**
- Read/Write vs Read-Only vs Blocked
- Values: `RW`, `RO`, `Blocked`
- Command: `storcli /cX/vX show all J`

**Why it's missing:**
- Rarely changed
- Security risk if automated

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Security sensitive
- ❌ Accidental changes could block access
- ❌ Better managed manually
- ❌ Rarely modified in practice

---

#### 5. VD Ongoing Operations ❌ SHOULD NOT ADD

**What it is:**
- Current migration status
- Background initialization progress
- Consistency check progress
- Values: Percentage, status strings
- Command: `storcli /cX/vX show all J`

**Why it's missing:**
- Highly volatile
- Changes constantly during operations

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Too volatile (changes every second during operations)
- ❌ Better suited for monitoring systems (not Puppet)
- ❌ Would cause constant fact updates
- ❌ No configuration management value

---

#### 6. VD Bad Blocks Table ❌ SHOULD NOT ADD

**What it is:**
- List of bad blocks on virtual drive
- Values: Array of LBA addresses
- Command: `storcli /cX/vX show all J`

**Why it's missing:**
- Volatile (changes when blocks fail)
- Monitoring data, not configuration

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Highly volatile
- ❌ Can be large (many bad blocks)
- ❌ Monitoring data (not config)
- ❌ Better in monitoring/alerting systems
- ❌ No puppet management value

---

## Physical Drive Information

### Currently Missing from Facts

#### 1. Physical Drive Summary Stats ⭐ SHOULD ADD

**What it is:**
- Total drive count by type (SSD, HDD)
- Total drive count by state (Online, Failed, Missing)
- Drive interface summary (SAS, SATA, NVMe)
- Values: Numeric counts
- Command: Aggregated from `storcli /cX/eall/sall show J`

**Why it's missing:**
- Not prioritized initially
- Focus was on VD-level configuration

**Should we add it?**
**YES** - Recommendation: **Add summary to controller facts**

**Reasoning:**
- ✅ Useful for capacity planning
- ✅ Helps identify failing drives
- ✅ Compact (just counts, not per-drive details)
- ✅ Relatively static
- ✅ Valuable for PuppetDB queries

**Implementation:**
```ruby
controller['physical_drives_summary'] = {
  'total_count' => total_drives,
  'online_count' => online_count,
  'failed_count' => failed_count,
  'ssd_count' => ssd_count,
  'hdd_count' => hdd_count,
}
```

---

#### 2. Per-Drive Details ❌ SHOULD NOT ADD

**What it is:**
- Individual drive properties (model, serial, size, state)
- 40+ properties per drive
- Command: `storcli /cX/eall/sall show all J`

**Why it's missing:**
- Would massively inflate fact size
- Too volatile

**Should we add it?**
**NO** - Recommendation: **Definitely do not add**

**Reasoning:**
- ❌ Huge data size (40+ fields × 100+ drives)
- ❌ Would make facts enormous
- ❌ Drive states change frequently
- ❌ Better suited for external monitoring
- ❌ Performance impact on Puppet runs
- ❌ PuppetDB would become drive inventory system

**Note:** This is monitoring data, not configuration data. Use dedicated monitoring tools.

---

#### 3. Drive Error Counters ❌ SHOULD NOT ADD

**What it is:**
- Media errors, other errors, predictive failures
- Shield counters, bad blocks
- Values: Numeric counters
- Command: `storcli /cX/eall/sall show all J`

**Why it's missing:**
- Highly volatile
- Monitoring data

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Changes constantly
- ❌ Monitoring data (use SNMP/monitoring tools)
- ❌ Large data volume
- ❌ Would trigger constant fact changes
- ❌ No configuration management value

---

#### 4. Drive Temperature ❌ SHOULD NOT ADD

**What it is:**
- Current temperature of each drive
- Values: Numeric (Celsius)
- Command: `storcli /cX/eall/sall show all J`

**Why it's missing:**
- Extremely volatile
- Monitoring data

**Should we add it?**
**NO** - Recommendation: **Absolutely do not add**

**Reasoning:**
- ❌ Changes every few seconds
- ❌ Classic monitoring metric (not config)
- ❌ Would cause constant fact updates
- ❌ Performance nightmare
- ❌ Use SNMP or monitoring agents

---

#### 5. Drive Power-On Hours / Power Cycle Count ❌ SHOULD NOT ADD

**What it is:**
- How long drive has been powered on
- Number of power cycles
- Values: Numeric
- Command: `storcli /cX/eall/sall show all J`

**Why it's missing:**
- Constantly increasing
- Monitoring/inventory data

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Always changing (increments hourly)
- ❌ Inventory data (not config)
- ❌ Better in asset management system
- ❌ Would cause constant fact updates

---

## BBU/CacheVault Information

### Currently Missing from Facts

#### 1. BBU Health Summary ⭐ SHOULD ADD

**What it is:**
- Battery health status
- Charge level
- Replacement needed flag
- Values: `Healthy`, `Warning`, `Failed`, percentage
- Command: `storcli /cX/bbu show J`

**Why it's missing:**
- Not prioritized in initial implementation
- Requires separate query

**Should we add it?**
**YES** - Recommendation: **Add BBU summary to controller facts**

**Reasoning:**
- ✅ Critical for cache protection
- ✅ Important for maintenance planning
- ✅ Relatively static (health doesn't change rapidly)
- ✅ Small data footprint
- ✅ High value for PuppetDB queries

**Implementation:**
```ruby
if bbu_data = get_bbu_status(controller_id)
  controller['bbu'] = {
    'state' => bbu_data['State'],
    'health' => bbu_data['Battery State'],
    'charge_percent' => bbu_data['Relative State of Charge'],
    'replacement_needed' => bbu_data['Pack is about to fail'],
  }
end
```

---

#### 2. BBU Detailed Metrics ❌ SHOULD NOT ADD

**What it is:**
- Voltage, current, temperature
- Cycle count, chemistry type
- Capacitance, impedance
- Values: Numeric measurements
- Command: `storcli /cX/bbu show all J`

**Why it's missing:**
- Too detailed
- Volatile measurements

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Volatile (voltage/current change constantly)
- ❌ Monitoring data (not config)
- ❌ Too detailed for configuration management
- ❌ Better in monitoring systems
- ❌ Most users don't need this level of detail

---

#### 3. BBU Design Capacity vs Full Charge Capacity ❌ SHOULD NOT ADD

**What it is:**
- Design capacity (new battery)
- Full charge capacity (current battery)
- Indicates battery degradation
- Values: Numeric (mAh)
- Command: `storcli /cX/bbu show all J`

**Why it's missing:**
- Too detailed
- Decreases over time (volatile)

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Too detailed
- ❌ Decreases gradually (volatile)
- ❌ Better for monitoring
- ❌ Health percentage is sufficient

---

## Enclosure Information

### Currently Missing from Facts

#### 1. Enclosure Count and Types ⚠️ MAYBE ADD

**What it is:**
- Number of enclosures
- Enclosure types (SGPIO, SES)
- Values: Numeric count, type strings
- Command: `storcli /cX/eall show J`

**Why it's missing:**
- Not prioritized
- Many systems have no external enclosures

**Should we add it?**
**MAYBE** - Recommendation: **Consider for future**

**Reasoning:**
- ⚠️ Useful for systems with external storage
- ⚠️ Many systems have no enclosures (value = 0)
- ✅ Relatively static
- ❌ Lower priority

---

#### 2. Enclosure Detailed Status ❌ SHOULD NOT ADD

**What it is:**
- Fan speeds, temperatures
- Power supply status
- Slot status, alarms
- Values: Many detailed fields
- Command: `storcli /cX/eall show all J`

**Why it's missing:**
- Monitoring data
- Too volatile

**Should we add it?**
**NO** - Recommendation: **Do not add**

**Reasoning:**
- ❌ Monitoring data (use SNMP)
- ❌ Temperature/fan changes constantly
- ❌ Better in monitoring systems
- ❌ No configuration management value

---

## Summary and Recommendations

### Settings to Add (High Priority)

1. **Load Balance Mode** - Controller setting
2. **Enclosure PD (enclpd)** - Controller setting
3. **Maintain PD Fail History** - Controller setting
4. **VD Stripe Size** - Virtual drive property
5. **VD Span Depth** - Virtual drive property
6. **VD Drives Per Span** - Virtual drive property
7. **Physical Drive Summary Stats** - Controller-level aggregates
8. **BBU Health Summary** - Battery status

**Implementation Impact:**
- Moderate: ~8 new fields across facts
- Size increase: ~100-200 bytes per controller
- Performance: Minimal (data already queried)
- Value: High (useful for config management)

### Settings to Consider (Medium Priority)

1. **Restore Hot Spare** - Controller setting
2. **Abort CC on Error** - Controller setting
3. **VD Boot Drive Status** - Virtual drive property
4. **VD Name/Label** - Virtual drive property
5. **Enclosure Count** - Controller summary

**Implementation Impact:**
- Low: ~5 fields
- Size increase: ~50-100 bytes
- Value: Medium (niche use cases)

### Settings to Exclude (Do Not Add)

1. **Controller Time** - Too volatile
2. **Enable Spin Down** - Too risky
3. **Spin Up Delay** - Rarely used
4. **Coercion Mode** - Too risky
5. **VD Ongoing Operations** - Too volatile
6. **VD Bad Blocks** - Monitoring data
7. **Per-Drive Details** - Too large
8. **Drive Error Counters** - Monitoring data
9. **Drive Temperature** - Too volatile
10. **Drive Power-On Hours** - Monitoring data
11. **BBU Detailed Metrics** - Monitoring data
12. **Enclosure Detailed Status** - Monitoring data

**Reasoning:**
- Volatile: Change too frequently
- Monitoring: Better suited for monitoring systems
- Too Large: Would bloat facts significantly
- Too Risky: Accidental automation could cause issues

### Implementation Priority

**Phase 1 (Immediate):**
- Add controller settings: loadbalancemode, enclpd, maintainpdflg
- Add VD static properties: stripe_size, span_depth, drives_per_span

**Phase 2 (Near-term):**
- Add BBU health summary
- Add physical drive summary stats

**Phase 3 (Future):**
- Consider niche settings based on user requests
- Evaluate enclosure information

### General Guidelines

**Add to Facts if:**
- ✅ Relatively static (doesn't change hourly/daily)
- ✅ Configuration-related (not monitoring)
- ✅ Small data footprint
- ✅ Useful for PuppetDB queries
- ✅ Helps with configuration management

**Do NOT Add to Facts if:**
- ❌ Changes constantly (volatile)
- ❌ Monitoring data (better in monitoring systems)
- ❌ Large data volume (per-drive details)
- ❌ Security risk if exposed
- ❌ Could cause accidental automation issues

**Remember:** 
- Facts should represent **configuration state**, not **runtime metrics**
- Use monitoring tools (Prometheus, Nagios, etc.) for volatile metrics
- PuppetDB is not an inventory system for every hardware detail
- Keep facts focused on what Puppet needs to manage

---

## Related Documentation

- [CONTROLLER_SETTINGS.md](CONTROLLER_SETTINGS.md) - Complete controller settings reference
- [UNMANAGED_FEATURES.md](UNMANAGED_FEATURES.md) - Features not currently managed
- [README.md](README.md) - Main module documentation
