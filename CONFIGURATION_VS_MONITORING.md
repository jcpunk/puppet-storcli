# Configuration vs Monitoring Data in megaraid Fact

## Purpose

This document explains the criteria used to decide which data to include in the `megaraid` fact and which to exclude. Puppet facts should focus on **configuration-relevant data** rather than monitoring metrics.

## Guiding Principles

### Include: Configuration Data

Data that should be in the fact:
- **Settings that affect behavior/policy** - How the system is configured
- **Settings you might want to enforce with Puppet** - Desired state that can be managed
- **Settings that change rarely and only via admin action** - Stable configuration
- **Capabilities and features** - What the hardware supports

Examples:
- RAID level (RAID0, RAID1, RAID5, etc.)
- Cache policies (WriteBack, WriteThrough, ReadAhead)
- Auto rebuild enabled/disabled
- Patrol read schedule
- Encryption status

### Exclude: Monitoring/Operational Data

Data that should NOT be in the fact:
- **Current operational state** - Real-time status that changes frequently
- **Performance metrics** - Counters, statistics, throughput
- **Historical counters** - Iteration counts, completion counts
- **Volatile system identifiers** - Device names that change on reboot (/dev/sda)
- **Inventory metadata** - Serial numbers of individual disks, creation timestamps

Examples:
- Current patrol read state (Running/Stopped)
- Number of patrol read iterations completed
- Current consistency check state
- Active operations (None/BGI/Rebuild)
- OS device names (/dev/sda, /dev/sdb)
- SCSI NAA identifiers

## Detailed Decision Matrix

### Patrol Read Properties

| Property | Include? | Type | Reasoning |
|----------|----------|------|-----------|
| PR Mode | ✅ Yes | Configuration | Schedule setting (Auto/Manual/Disabled) |
| PR Execution Delay | ✅ Yes | Configuration | How often patrol read runs |
| PR Next Start time | ✅ Yes | Configuration | When next run is scheduled |
| PR on SSD | ✅ Yes | Configuration | Whether SSDs are included in patrol read |
| PR Current State | ❌ No | Monitoring | Real-time operational state |
| PR iterations completed | ❌ No | Monitoring | Historical counter |
| PR Excluded VDs | ❌ No | Monitoring | Current exclusion list (changes) |
| PR MaxConcurrentPd | ❌ No | Monitoring | Performance tuning metric |

### Consistency Check Properties

| Property | Include? | Type | Reasoning |
|----------|----------|------|-----------|
| CC Operation Mode | ✅ Yes | Configuration | How CC runs (Concurrent/Sequential) |
| CC Execution Delay | ✅ Yes | Configuration | How often CC runs |
| CC Next Starttime | ✅ Yes | Configuration | When next run is scheduled |
| CC Current State | ❌ No | Monitoring | Real-time operational state |
| CC Number of iterations | ❌ No | Monitoring | Historical counter |
| CC Number of VD completed | ❌ No | Monitoring | Progress metric |
| CC Excluded VDs | ❌ No | Monitoring | Current exclusion list |

### Virtual Disk Properties

| Property | Include? | Type | Reasoning |
|----------|----------|------|-----------|
| Strip/Stripe Size | ✅ Yes | Configuration | RAID stripe configuration |
| Span Depth | ✅ Yes | Configuration | RAID span configuration |
| Number of Drives Per Span | ✅ Yes | Configuration | RAID configuration |
| Current Cache Policy | ✅ Yes | Configuration | Cache behavior setting |
| Current Write Policy | ✅ Yes | Configuration | Write behavior setting |
| Current Read Policy | ✅ Yes | Configuration | Read behavior setting |
| Disk Cache Policy | ✅ Yes | Configuration | Physical disk cache setting |
| Encryption | ✅ Yes | Configuration | Encryption status/type |
| Exposed to OS | ✅ Yes | Configuration | Whether VD is visible to OS |
| Unmap Enabled | ✅ Yes | Configuration | TRIM/UNMAP support |
| Data Protection | ✅ Yes | Configuration | Protection type (None/FDE) |
| Is VD Boot Drive | ✅ Yes | Configuration | Boot configuration |
| Number of Blocks | ❌ No | Inventory | Size metric (use Size field instead) |
| VD has Emulated PD | ❌ No | Implementation | Internal implementation detail |
| Active Operations | ❌ No | Monitoring | Current operations (BGI/Rebuild/None) |
| OS Drive Name | ❌ No | Volatile | Changes with device discovery order |
| Creation Date/Time | ❌ No | Historical | Historical metadata |
| Emulation type | ❌ No | Implementation | Internal implementation detail |
| Cachebypass size/Mode | ❌ No | Advanced | Rarely used, unclear value |
| Is LD Ready for OS Requests | ❌ No | Monitoring | Real-time readiness state |
| SCSI NAA Id | ❌ No | Inventory | Unique identifier (inventory system concern) |

### Controller Properties

| Property | Include? | Type | Reasoning |
|----------|----------|------|-----------|
| Product Name | ✅ Yes | Configuration | Hardware identification |
| Serial Number | ✅ Yes | Configuration | Hardware identification |
| FW Version | ✅ Yes | Configuration | Firmware version |
| BIOS Version | ✅ Yes | Configuration | BIOS version |
| Driver Name | ✅ Yes | Configuration | Kernel driver in use |
| Device Interface | ✅ Yes | Configuration | Interface type (SAS-12G) |
| Auto Rebuild | ✅ Yes | Configuration | Rebuild policy |
| Copy Back | ✅ Yes | Configuration | Copy back policy |
| JBOD Support | ✅ Yes | Configuration | JBOD capability |
| Alarm | ✅ Yes | Configuration | Alarm setting |
| Rebuild Rate | ✅ Yes | Configuration | Rebuild speed setting |

### BBU (Battery Backup Unit) Properties

| Property | Include? | Type | Reasoning |
|----------|----------|------|-----------|
| State | ✅ Yes | Configuration | Battery state (Optimal/Degraded) |
| Type | ✅ Yes | Configuration | Battery type (BBU/Capacitor) |
| Replacement Needed | ✅ Yes | Configuration | Whether replacement is needed |
| Learn Cycle Active | ✅ Yes | Configuration | Whether learn cycle is running |

## Rationale

Puppet is a **configuration management and state assurance system**. Facts should provide data that helps Puppet:

1. **Make configuration decisions** - Choose what to configure based on hardware capabilities
2. **Enforce desired state** - Know what settings are currently applied
3. **Detect drift** - Notice when configuration has changed from desired state

Monitoring systems (Prometheus, Nagios, etc.) are better suited for:
- Real-time operational state
- Performance metrics and trends  
- Alerting on transient conditions

By keeping facts focused on configuration data, we:
- Keep fact size small (Puppet has fact size limits)
- Improve fact collection performance (fewer queries)
- Provide clearer semantics (facts = configuration)
- Reduce noise in Puppet reports

## Consumer Guidance

When using the megaraid fact in Puppet manifests:

```puppet
# ✅ Good: Using configuration data for decisions
if $facts['megaraid']['controllers']['0']['controller_settings']['Auto Rebuild'] == 'Off' {
  notify { 'Auto rebuild is disabled, consider enabling': }
}

# ✅ Good: Enforcing cache policy configuration
$desired_cache = 'WriteBack'
$current_cache = $facts['megaraid']['controllers']['0']['drive_groups']['0']['virtual_disks']['0']['properties']['current_cache_policy']
if $current_cache != $desired_cache {
  notify { "Cache policy drift detected: ${current_cache} != ${desired_cache}": }
}

# ❌ Bad: Using monitoring data (not in fact)
# This won't work because 'PR Current State' is not in the fact (monitoring data)
if $facts['megaraid']['controllers']['0']['patrol_read']['current_state'] == 'Running' {
  # This is monitoring, not configuration - use a monitoring system instead
}
```

For monitoring current operational state, use appropriate monitoring tools that poll the hardware directly.
