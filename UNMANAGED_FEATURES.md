# Unmanaged Features Analysis

This document analyzes storcli/perccli features that the module **cannot currently manage**, along with proposals for how they might be added, whether it's a good idea, and how to collect fixture data.

## Table of Contents

1. [Overview](#overview)
2. [Hot Spare Management](#hot-spare-management)
3. [Physical Drive Operations](#physical-drive-operations)
4. [Foreign Configuration Management](#foreign-configuration-management)
5. [Virtual Drive Creation/Deletion](#virtual-drive-creationdeletion)
6. [BBU/CacheVault Management](#bbucachevault-management)
7. [Enclosure Management](#enclosure-management)
8. [Drive Firmware Updates](#drive-firmware-updates)
9. [Event Log Management](#event-log-management)
10. [Advanced Features](#advanced-features)
11. [Implementation Priority](#implementation-priority)
12. [Fixture Collection Guide](#fixture-collection-guide)

## Overview

### Currently Managed

The module currently manages:
- ✅ Controller settings (autorebuild, alarm, cache, etc.)
- ✅ Virtual drive cache policies (wrcache, rdcache, iopolicy, pdcache)
- ✅ Patrol read configuration
- ✅ Consistency check configuration
- ✅ Time synchronization

### Not Currently Managed

This document analyzes:
- ❓ Hot spare management
- ❓ Physical drive operations
- ❓ Foreign configuration handling
- ❓ Virtual drive creation/deletion
- ❓ BBU/CacheVault management
- ❓ Drive/controller firmware updates
- ❓ Event log management
- ❓ Other advanced features

## Hot Spare Management

### Feature Description

**What it is:**
- Designate drives as hot spares for automatic failover
- Types: Global (any VD) or Dedicated (specific VD)
- Automatic replacement when drive fails

**Commands:**
```bash
# Add global hot spare
storcli /c0/e252/s5 add hotsparedrive

# Add dedicated hot spare
storcli /c0/e252/s5 add hotsparedrive dgs=0

# Remove hot spare
storcli /c0/e252/s5 delete hotsparedrive
```

### Should We Manage This?

**Recommendation: ⭐ YES - HIGH PRIORITY**

**Pros:**
- ✅ Critical for RAID availability
- ✅ Safe operation (doesn't touch data)
- ✅ Clear state management (spare vs non-spare)
- ✅ Common requirement for production systems
- ✅ Fits Puppet's declarative model well

**Cons:**
- ⚠️ Requires unused drives
- ⚠️ Must not designate drives with data

**Risk Level: LOW** - Safe operation if implemented correctly

### Proposed Implementation

**Custom Type:** `megaraid_hotspare`

```puppet
megaraid_hotspare { '0:252:5':
  ensure     => present,
  type       => 'global',  # or 'dedicated'
  dgs        => [0, 1],    # for dedicated spares
}
```

**Type Properties:**
- `ensure`: present/absent
- `controller`: Controller ID
- `enclosure`: Enclosure ID
- `slot`: Slot ID
- `type`: global/dedicated
- `dgs`: Array of drive groups (for dedicated)

**Provider Implementation:**
```ruby
def create
  if @resource[:type] == 'global'
    execute_command("/c#{controller}/e#{enclosure}/s#{slot} add hotsparedrive")
  else
    dgs = @resource[:dgs].join(',')
    execute_command("/c#{controller}/e#{enclosure}/s#{slot} add hotsparedrive dgs=#{dgs}")
  end
end

def exists?
  output = execute_command("/c#{controller}/e#{enclosure}/s#{slot} show J", use_json: true)
  drive_data = parse_json_response(output)
  drive_data['State'] == 'GHS' || drive_data['State'] == 'DHS'
end
```

### Fixture Requirements

**Files needed:**
```bash
# Show all drives including hot spares
storcli /c0/eall/sall show J nolog > spec/fixtures/MODEL/storcli_call_eall_sall_show.json

# Show specific hot spare
storcli /c0/e252/s5 show J nolog > spec/fixtures/MODEL/storcli_c0_e252_s5_show.json
```

**Example fixture structure:**
```json
{
  "Controllers": [{
    "Response Data": {
      "Drive /c0/e252/s5": [{
        "EID:Slt": "252:5",
        "DID": 8,
        "State": "GHS",  // Global Hot Spare
        "DG": "-",
        "Size": "1.818 TB",
        "Intf": "SATA",
        "Med": "HDD"
      }]
    }
  }]
}
```

### Implementation Effort

- **Complexity:** Medium
- **Testing:** Requires actual hardware with spare drives
- **Documentation:** 1-2 hours
- **Coding:** 4-6 hours
- **Total:** 2-3 days

---

## Physical Drive Operations

### Feature Description

**What it is:**
- Operations on individual drives
- Initialize, make good, spindown, locate
- State changes (online, offline, missing, JBOD)

**Commands:**
```bash
# Initialize drive (erase)
storcli /c0/e252/s5 start initialization

# Make good (clear errors)
storcli /c0/e252/s5 makegood force

# Set to JBOD mode
storcli /c0/e252/s5 set jbod

# Spin down drive
storcli /c0/e252/s5 spindown

# Locate drive (blink LED)
storcli /c0/e252/s5 start locate
storcli /c0/e252/s5 stop locate
```

### Should We Manage This?

**Recommendation: ⚠️ CAUTION - VERY RISKY**

**Pros:**
- ✅ Could automate drive preparation
- ✅ Could automate drive location for replacement

**Cons:**
- ❌ **HIGH RISK** - Can erase data
- ❌ Drive initialization is destructive
- ❌ Accidental automation could cause data loss
- ❌ State changes can make drives unavailable
- ❌ Better suited for manual operations

**Risk Level: VERY HIGH** - Could cause catastrophic data loss

### Proposed Implementation (If At All)

**Recommendation: FACTS ONLY - NO MANAGEMENT**

Instead of managing drive operations, just add drive facts:

```ruby
# In facter
controller['physical_drives_summary'] = {
  'total_count' => total_drives,
  'online_count' => online_drives,
  'offline_count' => offline_drives,
  'failed_count' => failed_drives,
  'rebuilding_count' => rebuilding_drives,
  'unconfigured_good_count' => unconfigured_good,
  'unconfigured_bad_count' => unconfigured_bad,
}
```

**Do NOT create type for:**
- ❌ Drive initialization (too risky)
- ❌ Drive state changes (too risky)
- ❌ Make good operations (risky)

**Could consider type for safe operations:**
- ✅ Locate LED (blink/unblink) - Safe, useful
- ✅ Spindown unconfigured drives - Moderate risk

**If implementing locate LED:**
```puppet
megaraid_drive_locate { '0:252:5':
  ensure => blinking,  # or off
}
```

### Fixture Requirements

**Files needed:**
```bash
# All drives with detailed status
storcli /c0/eall/sall show all J nolog > spec/fixtures/MODEL/storcli_call_eall_sall_show_all.json
```

### Implementation Effort

- **Facts only:** 2-4 hours
- **Locate LED type:** 4-6 hours
- **Full management (NOT RECOMMENDED):** Don't do it

---

## Foreign Configuration Management

### Feature Description

**What it is:**
- Foreign configurations are detected when drives with RAID metadata are moved between controllers
- Must be imported or cleared before drives can be used
- Common scenario: replacing failed controller

**Commands:**
```bash
# Show foreign configuration
storcli /c0/fall show J

# Import foreign configuration
storcli /c0/fall import

# Clear foreign configuration
storcli /c0/fall delete
```

### Should We Manage This?

**Recommendation: ⭐ YES - IMPORTANT FEATURE**

**Pros:**
- ✅ Common scenario (drive moves, controller replacement)
- ✅ Safe to automate with proper checks
- ✅ Predictable operation
- ✅ Clear use cases

**Cons:**
- ⚠️ Clearing foreign config erases metadata (but not data)
- ⚠️ Need to decide: import vs clear

**Risk Level: MEDIUM** - Safe with proper implementation

### Proposed Implementation

**Custom Type:** `megaraid_foreign_config`

```puppet
megaraid_foreign_config { 'controller_0':
  ensure     => 'imported',  # or 'cleared'
  controller => 0,
}
```

**Type Properties:**
- `ensure`: imported/cleared/preview
- `controller`: Controller ID

**Provider Implementation:**
```ruby
def exists?
  output = execute_command("/c#{@resource[:controller]}/fall show J", use_json: true)
  data = parse_json_response(output)
  
  # Check if foreign config exists
  return :cleared if data['No foreign configuration']
  return :imported if data['Foreign Configuration'] && data['Status'] == 'Imported'
  return :detected # Foreign config detected but not imported
end

def create
  case @resource[:ensure]
  when :imported
    execute_command("/c#{@resource[:controller]}/fall import nolog")
  when :cleared
    execute_command("/c#{@resource[:controller]}/fall delete nolog")
  end
end
```

**Manifest Usage:**
```puppet
# Automatically import foreign configs
megaraid_foreign_config { 'auto_import':
  ensure => imported,
}
```

### Fixture Requirements

**Files needed:**
```bash
# Foreign configuration status
storcli /c0/fall show J nolog > spec/fixtures/MODEL/storcli_c0_fall_show.json

# After import
storcli /c0/fall show J nolog > spec/fixtures/MODEL/storcli_c0_fall_show_imported.json
```

**Example fixture:**
```json
{
  "Controllers": [{
    "Response Data": {
      "Foreign Configuration": [{
        "VD": 0,
        "DG": 0,
        "Size": "1.818 TB",
        "State": "Foreign",
        "Type": "RAID5"
      }]
    }
  }]
}
```

### Implementation Effort

- **Complexity:** Medium
- **Testing:** Requires drives with foreign config
- **Coding:** 6-8 hours
- **Total:** 3-4 days

---

## Virtual Drive Creation/Deletion

### Feature Description

**What it is:**
- Create new virtual drives (RAID arrays)
- Delete existing virtual drives
- Modify VD properties

**Commands:**
```bash
# Create RAID 5
storcli /c0 add vd r5 drives=252:5-8

# Delete VD
storcli /c0/v0 del force

# Modify VD
storcli /c0/v0 set name=MyVD
```

### Should We Manage This?

**Recommendation: ❌ NO - TOO RISKY**

**Pros:**
- ✅ Could enable full infrastructure-as-code
- ✅ Could automate new system setup

**Cons:**
- ❌ **EXTREME RISK** - Can erase all data
- ❌ VD deletion is catastrophic
- ❌ VD creation requires very specific knowledge
- ❌ One wrong automation = data loss
- ❌ RAID level selection is critical decision
- ❌ Drive selection must be manual
- ❌ Better suited for initial provisioning (manual)

**Risk Level: EXTREME** - Don't automate this

### Alternative Approach

**Recommendation: VALIDATION ONLY**

Instead of creating VDs, validate they exist as expected:

```puppet
# Check VD exists with expected properties
megaraid_vd_validation { '0/0':
  ensure      => present,
  raid_level  => '5',
  size_min_gb => 1000,
  state       => 'Optimal',
}
```

This would:
- ✅ Verify VD exists
- ✅ Alert if misconfigured
- ❌ NOT create or delete VDs

### Fixture Requirements

**If implementing validation only:**
```bash
# VD details for validation
storcli /c0/vall show all J nolog > spec/fixtures/MODEL/storcli_c0_vall_show_all.json
```

### Implementation Effort

- **Creation/Deletion (NOT RECOMMENDED):** Don't do it
- **Validation only:** 4-6 hours

---

## BBU/CacheVault Management

### Feature Description

**What it is:**
- Battery backup unit or CacheVault management
- Learn cycles, autolearn settings
- Battery status and replacement

**Commands:**
```bash
# Show BBU status
storcli /c0/bbu show J

# Start learn cycle
storcli /c0/bbu start learn

# Set autolearn mode
storcli /c0/bbu set autolearn on
storcli /c0/bbu set autolearndelay 30
```

### Should We Manage This?

**Recommendation: ⭐ YES - USEFUL FEATURE**

**Pros:**
- ✅ Important for cache protection
- ✅ Learn cycles should be scheduled
- ✅ Autolearn settings are configuration
- ✅ Safe operations (don't affect data)

**Cons:**
- ⚠️ Learn cycle impacts performance
- ⚠️ Not all controllers have BBU

**Risk Level: LOW** - Safe to automate

### Proposed Implementation

**Custom Type:** `megaraid_bbu`

```puppet
megaraid_bbu { 'controller_0':
  controller         => 0,
  autolearn          => on,
  autolearn_delay    => 30,  # days
  autolearn_mode     => 'warn',  # warn, transparent, or off
}
```

**Type Properties:**
- `controller`: Controller ID
- `autolearn`: on/off
- `autolearn_delay`: Days between learn cycles
- `autolearn_mode`: warn/transparent/off

**Provider Implementation:**
```ruby
def autolearn
  output = execute_command("/c#{@resource[:controller]}/bbu show J", use_json: true)
  data = parse_json_response(output)
  data['Auto Learn Mode'] == 'Enabled' ? :on : :off
end

def autolearn=(value)
  execute_command("/c#{@resource[:controller]}/bbu set autolearn #{value} nolog")
end
```

**Note:** Do NOT automate:
- ❌ Learn cycle initiation (performance impact)
- ❌ Battery replacement (hardware operation)

### Fixture Requirements

**Files needed:**
```bash
# BBU status
storcli /c0/bbu show J nolog > spec/fixtures/MODEL/storcli_c0_bbu_show.json

# Detailed BBU info
storcli /c0/bbu show all J nolog > spec/fixtures/MODEL/storcli_c0_bbu_show_all.json
```

**Example fixture:**
```json
{
  "Controllers": [{
    "Response Data": {
      "BBU_Info": [{
        "Model": "CVPM02",
        "State": "Optimal",
        "Design Capacity": "1100 mAh",
        "Full Charge Capacity": "995 mAh",
        "Relative State of Charge": "100 %",
        "Auto Learn Mode": "Enabled",
        "Auto Learn Delay": "30 Days"
      }]
    }
  }]
}
```

### Implementation Effort

- **Complexity:** Medium
- **Testing:** Requires controller with BBU
- **Coding:** 6-8 hours
- **Total:** 3-4 days

---

## Enclosure Management

### Feature Description

**What it is:**
- External enclosure management
- Fan speed, temperature monitoring
- Alarm settings

**Commands:**
```bash
# Show enclosure status
storcli /c0/eall show J

# Show detailed enclosure info
storcli /c0/e252 show all J
```

### Should We Manage This?

**Recommendation: 📊 FACTS ONLY - NO MANAGEMENT**

**Pros for Management:**
- ✅ Could set alarm policies
- ✅ Could manage enclosure settings

**Cons for Management:**
- ❌ Most settings are monitoring-related
- ❌ Temperature/fan are volatile
- ❌ Limited configuration options
- ❌ Niche use case

**Risk Level: LOW** - But limited value

### Proposed Implementation

**Recommendation: Add to facts only**

```ruby
# In facter
controller['enclosures'] = {
  'count' => enclosure_count,
  'types' => ['SGPIO', 'SES'],  # Types present
}
```

**Do NOT create management type** - limited configuration options

### Fixture Requirements

**Files needed:**
```bash
# Enclosure summary
storcli /c0/eall show J nolog > spec/fixtures/MODEL/storcli_c0_eall_show.json

# Detailed enclosure (if present)
storcli /c0/e252 show all J nolog > spec/fixtures/MODEL/storcli_c0_e252_show_all.json
```

### Implementation Effort

- **Facts only:** 2-3 hours
- **Management (NOT RECOMMENDED):** 6-8 hours

---

## Drive Firmware Updates

### Feature Description

**What it is:**
- Update firmware on drives or controller
- Download and apply firmware

**Commands:**
```bash
# Update controller firmware
storcli /c0 download file=/path/to/firmware.bin

# Update drive firmware
storcli /c0/e252/s5 download file=/path/to/drive.bin
```

### Should We Manage This?

**Recommendation: ❌ ABSOLUTELY NOT**

**Pros:**
- ✅ Could automate firmware updates

**Cons:**
- ❌ **EXTREME RISK** - Firmware updates can brick hardware
- ❌ Failed update can destroy controller
- ❌ Requires reboot/interruption
- ❌ Can cause data loss
- ❌ Requires careful planning and testing
- ❌ Should never be automated
- ❌ One wrong file = dead hardware

**Risk Level: CATASTROPHIC**

### Alternative

**Don't do this.** Period.

Firmware updates should:
- Be done manually
- With maintenance windows
- With backups
- With rollback plans
- One system at a time
- With validation at each step

### Fixture Requirements

None - don't implement this feature.

---

## Event Log Management

### Feature Description

**What it is:**
- Controller event logs
- Error events, warning events
- Drive events, VD events

**Commands:**
```bash
# Show events
storcli /c0 show events

# Show specific event types
storcli /c0 show events filter=critical

# Clear events
storcli /c0 show events clear
```

### Should We Manage This?

**Recommendation: 📊 MONITORING INTEGRATION**

**Pros:**
- ✅ Could export events to monitoring
- ✅ Could alert on critical events

**Cons:**
- ❌ Highly volatile (new events constantly)
- ❌ Better suited for monitoring tools
- ❌ Not configuration management

**Risk Level: LOW** - But wrong tool for the job

### Proposed Implementation

**Recommendation: External integration, not Puppet type**

Create a monitoring plugin instead:
```bash
#!/bin/bash
# Check for critical events
storcli /c0 show events filter=critical J nolog | \
  check-for-new-events.sh
```

**Integration options:**
- Nagios/Icinga plugin
- Prometheus exporter
- Logstash input
- External script (not Puppet)

**Do NOT:**
- ❌ Add events to Puppet facts (too volatile)
- ❌ Create Puppet type for events
- ❌ Try to "manage" events with Puppet

### Fixture Requirements

**For monitoring integration:**
```bash
# Sample events for testing
storcli /c0 show events J nolog > spec/fixtures/MODEL/storcli_c0_show_events.json
```

### Implementation Effort

- **Puppet integration (NOT RECOMMENDED):** Don't do it
- **Monitoring plugin:** 4-6 hours (separate project)

---

## Advanced Features

### 1. Copyback Operations ⚠️ MAYBE

**What:** Auto-copy data from spare back to replaced drive

**Currently:** Module supports copyback setting but not triggering operation

**Should we manage triggering?** NO - automatic process, don't interfere

---

### 2. Migration Operations ❌ NO

**What:** Migrate VD between RAID levels or expand

**Risk:** EXTREME - data loss if interrupted

**Should we manage?** NO - too risky

---

### 3. Background Initialization Control ❌ NO

**What:** Control BGI rate, pause/resume

**Current:** Module supports BGI rate setting

**Should we manage pause/resume?** NO - performance-related, not config

---

### 4. Consistency Check Triggering ⚠️ MAYBE

**What:** Trigger manual CC

**Current:** Module manages CC settings but not triggering

**Should we add trigger?** MAYBE - but only in maintenance mode

---

### 5. Drive Secure Erase ❌ ABSOLUTELY NOT

**What:** Securely erase drive data

**Risk:** CATASTROPHIC

**Should we manage?** ABSOLUTELY NOT

---

## Implementation Priority

Based on value vs risk analysis:

### Tier 1: High Priority (Should Implement)

1. **Hot Spare Management** ⭐⭐⭐
   - High value: Critical for availability
   - Low risk: Safe operation
   - Common use case
   - Effort: 2-3 days

2. **Foreign Configuration Management** ⭐⭐⭐
   - High value: Common scenario
   - Medium risk: With proper checks
   - Clear use case
   - Effort: 3-4 days

3. **BBU Management** ⭐⭐
   - Medium-high value: Important for cache
   - Low risk: Safe operations
   - Configuration-focused
   - Effort: 3-4 days

### Tier 2: Medium Priority (Consider)

4. **Physical Drive Summary Facts** ⭐⭐
   - Medium value: Useful for inventory
   - No risk: Facts only
   - Effort: 2-3 hours

5. **Enclosure Facts** ⭐
   - Low-medium value: Niche use case
   - No risk: Facts only
   - Effort: 2-3 hours

### Tier 3: Low Priority (Maybe Later)

6. **Drive Locate LED** ⭐
   - Low value: Nice to have
   - No risk: Just blinks LED
   - Effort: 4-6 hours

### Never Implement

- ❌ Virtual Drive Creation/Deletion
- ❌ Drive Firmware Updates
- ❌ Drive Initialization
- ❌ Secure Erase
- ❌ Any destructive operation

---

## Fixture Collection Guide

### For Hot Spare Management

```bash
# System with hot spares configured
storcli /c0/eall/sall show J nolog > storcli_call_eall_sall_show.json
storcli /c0/dall show J nolog > storcli_c0_dall_show.json

# Individual hot spare
storcli /c0/e252/s5 show J nolog > storcli_c0_e252_s5_show.json
```

### For Foreign Configuration

```bash
# System with foreign config detected
storcli /c0/fall show J nolog > storcli_c0_fall_show.json

# After importing
storcli /c0/fall show J nolog > storcli_c0_fall_show_imported.json

# No foreign config
storcli /c0/fall show J nolog > storcli_c0_fall_show_none.json
```

### For BBU Management

```bash
# BBU status
storcli /c0/bbu show J nolog > storcli_c0_bbu_show.json

# Detailed BBU info
storcli /c0/bbu show all J nolog > storcli_c0_bbu_show_all.json

# System with CacheVault instead
storcli /c0/cv show J nolog > storcli_c0_cv_show.json
```

### For Physical Drive Stats

```bash
# All drives summary
storcli /c0/eall/sall show J nolog > storcli_c0_eall_sall_show.json

# Detailed drive info (for reference)
storcli /c0/eall/sall show all J nolog > storcli_c0_eall_sall_show_all.json
```

### For Enclosure Facts

```bash
# Enclosures list
storcli /c0/eall show J nolog > storcli_c0_eall_show.json

# Detailed enclosure (if external enclosure present)
storcli /c0/e252 show all J nolog > storcli_c0_e252_show_all.json
```

### Directory Structure

```
spec/fixtures/MODEL/
├── storcli_call_show.json               # Main controller info (existing)
├── storcli_call_show_patrolread.json    # Patrol read (existing)
├── storcli_call_show_cc.json            # Consistency check (existing)
├── storcli_call_show_vdiskX.json        # VD info (existing)
├── storcli_call_eall_sall_show.json     # All drives (NEW)
├── storcli_c0_dall_show.json            # Drive groups (NEW)
├── storcli_c0_fall_show.json            # Foreign config (NEW)
├── storcli_c0_bbu_show.json             # BBU status (NEW)
├── storcli_c0_bbu_show_all.json         # BBU detailed (NEW)
└── storcli_c0_eall_show.json            # Enclosures (NEW)
```

### Validation

After collecting fixtures, validate JSON:
```bash
for file in spec/fixtures/MODEL/*.json; do
  echo "Validating $file"
  jq empty "$file" || echo "INVALID: $file"
done
```

---

## Summary

### Features to Implement

| Feature | Priority | Risk | Effort | Value |
|---------|----------|------|--------|-------|
| Hot Spare Management | ⭐⭐⭐ High | Low | 2-3 days | High |
| Foreign Config | ⭐⭐⭐ High | Medium | 3-4 days | High |
| BBU Management | ⭐⭐ Medium | Low | 3-4 days | Medium-High |
| PD Summary Facts | ⭐⭐ Medium | None | 2-3 hours | Medium |
| Enclosure Facts | ⭐ Low | None | 2-3 hours | Low |
| Drive Locate LED | ⭐ Low | None | 4-6 hours | Low |

### Features to Never Implement

- ❌ Virtual Drive Creation/Deletion (extreme risk)
- ❌ Drive Firmware Updates (catastrophic risk)
- ❌ Drive Initialization (high risk)
- ❌ Secure Erase (catastrophic risk)
- ❌ Event Log Management (wrong tool)

### Decision Framework

**Implement if:**
- ✅ Configuration-related (not monitoring)
- ✅ Safe operation (no data loss risk)
- ✅ Common use case
- ✅ Fits declarative model
- ✅ Puppet is the right tool

**Don't implement if:**
- ❌ High risk of data loss
- ❌ Hardware damage potential
- ❌ Better suited for monitoring tools
- ❌ Requires manual judgment
- ❌ Volatile/rapidly changing

### Next Steps

1. Implement hot spare management (highest priority)
2. Implement foreign config handling
3. Add BBU management
4. Enhance facts with PD summary
5. Consider drive locate LED based on user requests

---

## Related Documentation

- [MISSING_FACT_SETTINGS.md](MISSING_FACT_SETTINGS.md) - Settings not in facts
- [CONTROLLER_SETTINGS.md](CONTROLLER_SETTINGS.md) - Controller settings reference
- [FIXTURE_COLLECTION_GUIDE.md](FIXTURE_COLLECTION_GUIDE.md) - Fixture collection guide
- [README.md](README.md) - Main module documentation
