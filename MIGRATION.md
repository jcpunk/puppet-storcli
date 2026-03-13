# Migration Guide: v1.x to v2.0

## Overview

Version 2.0 is a major API-breaking refactor that replaces the flat parameter structure with a Hash-based approach and introduces custom Puppet types and providers for improved resource management.

## Breaking Changes

### Parameter Structure

**Old (v1.x):**
```puppet
class { 'storcli':
  controller_manage_rebuild       => true,
  controller_autorebuild          => true,
  controller_rebuildrate          => 60,
  controller_perfmode             => 0,
  controller_ncq                  => true,
  controller_cacheflushinterval   => 4,
  controller_bootwithpinnedcache  => false,
  controller_manage_alarm         => true,
  controller_alarm                => true,
  controller_smartpollinterval    => 60,
  controller_patrolread_mode      => 'auto',
  controller_patrolread_delay     => 336,
  controller_patrolread_rate      => 30,
  controller_patrolread_includessds   => false,
  controller_patrolread_uncfgareas    => false,
  controller_consistencycheck_mode    => 'conc',
  controller_consistencycheck_delay   => 672,
  controller_consistencycheck_rate    => 30,
}
```

**New (v2.0):**
```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild                => true,
    rebuildrate                => 60,
    perfmode                   => 0,
    ncq                        => true,
    cacheflushinterval         => 4,
    bootwithpinnedcache        => false,
    alarm                      => true,
    smartpollinterval          => 60,
    patrolread_mode            => 'auto',
    patrolread_delay           => 336,
    patrolread_rate            => 30,
    patrolread_includessds     => false,
    patrolread_uncfgareas      => false,
    consistencycheck_mode      => 'conc',
    consistencycheck_delay     => 672,
    consistencycheck_rate      => 30,
  },
  controller_overrides => {},
  vd_defaults          => {},
  vd_overrides         => {},
}
```

### Removed Parameters

- `controller_manage_rebuild` - No longer needed; settings are only managed if specified in the Hash
- `controller_manage_alarm` - No longer needed; settings are only managed if specified in the Hash

### Parameter Name Changes

All `controller_*` parameters have been moved into the `controller_defaults` Hash without the `controller_` prefix:

- `controller_autorebuild` → `autorebuild` (in Hash)
- `controller_rebuildrate` → `rebuildrate` (in Hash)
- `controller_perfmode` → `perfmode` (in Hash)
- `controller_ncq` → `ncq` (in Hash)
- `controller_cacheflushinterval` → `cacheflushinterval` (in Hash)
- `controller_bootwithpinnedcache` → `bootwithpinnedcache` (in Hash)
- `controller_alarm` → `alarm` (in Hash)
- `controller_smartpollinterval` → `smartpollinterval` (in Hash)
- `controller_patrolread_mode` → `patrolread_mode` (in Hash)
- `controller_patrolread_delay` → `patrolread_delay` (in Hash)
- `controller_patrolread_rate` → `patrolread_rate` (in Hash)
- `controller_patrolread_includessds` → `patrolread_includessds` (in Hash)
- `controller_patrolread_uncfgareas` → `patrolread_uncfgareas` (in Hash)
- `controller_consistencycheck_mode` → `consistencycheck_mode` (in Hash)
- `controller_consistencycheck_delay` → `consistencycheck_delay` (in Hash)
- `controller_consistencycheck_rate` → `consistencycheck_rate` (in Hash)

## New Features

### Per-Controller Overrides

You can now specify different settings for individual controllers:

```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild => true,
    rebuildrate => 60,
    alarm       => true,
  },
  controller_overrides => {
    1 => {
      alarm       => false,  # Controller 1 has alarm disabled
      rebuildrate => 30,     # Controller 1 uses different rebuild rate
    },
  },
}
```

### Virtual Drive Cache Settings

Version 2.0 adds support for managing virtual drive cache policies:

```puppet
class { 'storcli':
  vd_defaults => {
    wrcache  => 'wt',      # Write-through cache
    rdcache  => 'ra',      # Read-ahead cache
    iopolicy => 'direct',  # Direct I/O
    pdcache  => 'default', # Use disk's default cache setting
  },
  vd_overrides => {
    '0/0' => {             # Override for controller 0, VD 0
      wrcache => 'wb',     # Use write-back for this VD
    },
  },
}
```

### Pick-and-Choose Settings

You no longer need to specify all settings. Only the settings you include in the Hashes will be managed:

```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild => true,
    alarm       => false,
  },
  # Only autorebuild and alarm will be managed
  # All other settings remain untouched
}
```

## Migration Steps

### Step 1: Update Hiera Data

**Before (data/common.yaml):**
```yaml
storcli::controller_manage_rebuild: true
storcli::controller_autorebuild: true
storcli::controller_rebuildrate: 60
storcli::controller_alarm: true
```

**After (data/common.yaml):**
```yaml
storcli::controller_defaults:
  autorebuild: true
  rebuildrate: 60
  alarm: true

storcli::controller_overrides: {}
storcli::vd_defaults: {}
storcli::vd_overrides: {}
```

### Step 2: Update Module Declarations

If you're declaring the class directly in manifests:

**Before:**
```puppet
class { 'storcli':
  controller_autorebuild => true,
  controller_alarm       => false,
}
```

**After:**
```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild => true,
    alarm       => false,
  },
  controller_overrides => {},
  vd_defaults          => {},
  vd_overrides         => {},
}
```

### Step 3: Test the Changes

1. Run Puppet in `--noop` mode to see what changes would be made
2. Review the catalog to ensure resources are created correctly
3. Apply changes to a test system first
4. Monitor the results before rolling out to production

## Implementation Details

### Custom Types

Version 2.0 introduces custom Puppet types that replace the previous exec-based approach:

- `megaraid_controller_setting` - Individual controller settings
- `megaraid_patrolread` - Patrol read configuration
- `megaraid_consistency_check` - Consistency check configuration
- `megaraid_vd_setting` - Virtual drive cache policies

These types provide:
- Idempotent resource management
- Better error handling
- Improved state detection
- Cleaner catalog output

## Support

If you encounter issues during migration, please open an issue on the GitHub repository.
