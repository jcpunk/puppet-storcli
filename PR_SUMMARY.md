# API-Breaking Refactor: Custom Types and Hash-Based Configuration

## Summary

This PR implements a comprehensive API-breaking refactor of the puppet-storcli module, modernizing it from exec-based configuration to proper Puppet custom types and providers, while introducing flexible Hash-based parameter structure.

## Changes Overview

### Statistics
- **25 files changed**: 1,985 insertions(+), 914 deletions(-)
- **Version**: Bumped from 1.2.0 to 2.0.0
- **New files**: 12 custom type/provider files, 4 private manifest classes, 4 unit test files, 2 documentation files

### Major Components

#### 1. Custom Puppet Types and Providers (8 new files)

**Types:**
- `megaraid_controller_setting` - Manages individual controller settings
- `megaraid_vd_setting` - Manages virtual drive cache policies (NEW feature)
- `megaraid_patrolread` - Manages patrol read configuration
- `megaraid_consistency_check` - Manages consistency check configuration

**Providers:**
- All providers use `storcli`/`perccli` via facts
- Idempotent resource management with proper state detection
- JSON output parsing where available
- Automatic `nolog` appending to all commands

#### 2. Hash-Based Parameter Structure

**Before (v1.x):**
```puppet
class { 'storcli':
  controller_manage_rebuild => true,
  controller_autorebuild    => true,
  controller_rebuildrate    => 60,
  controller_alarm          => true,
  # ... 20+ flat parameters
}
```

**After (v2.0):**
```puppet
class { 'storcli':
  controller_defaults => {
    autorebuild => true,
    rebuildrate => 60,
    alarm       => true,
  },
  controller_overrides => {
    1 => { alarm => false },  # Per-controller override
  },
  vd_defaults => {
    wrcache  => 'wt',
    rdcache  => 'ra',
    iopolicy => 'direct',
  },
}
```

#### 3. Modular Class Architecture (4 new classes)

Split monolithic `configure.pp` (357 lines) into:
- `storcli::configure` - Orchestrator class
- `storcli::configure::controller` - Controller settings (@api private)
- `storcli::configure::patrolread` - Patrol read settings (@api private)
- `storcli::configure::consistencycheck` - Consistency check settings (@api private)
- `storcli::configure::virtual_drives` - VD cache settings (@api private)

#### 4. New Features

**Virtual Drive Cache Management:**
- `wrcache` - Write cache policy: wt, wb, awb
- `rdcache` - Read cache: ra, nora
- `iopolicy` - IO policy: direct, cached
- `pdcache` - Physical drive cache: on, off, default

**Per-Controller Overrides:**
- Different settings for each controller
- Solves the heterogeneous environment problem

**Pick-and-Choose Settings:**
- Only specified settings are managed
- Unspecified settings remain unchanged
- Natural implementation via Hash structure

#### 5. Test Coverage

**Updated Tests:**
- Complete rewrite of `spec/classes/configure_spec.rb` (649 lines → modern structure)
- Updated `spec/classes/storcli_spec.rb` for new parameters

**New Unit Tests:**
- `spec/unit/puppet/type/megaraid_controller_setting_spec.rb`
- `spec/unit/puppet/type/megaraid_vd_setting_spec.rb`
- `spec/unit/puppet/type/megaraid_patrolread_spec.rb`
- `spec/unit/puppet/type/megaraid_consistency_check_spec.rb`

#### 6. Documentation

**New Documentation:**
- `MIGRATION.md` - Comprehensive v1.x to v2.0 migration guide
- `CHANGELOG.md` - Detailed v2.0 release notes

**Updated Documentation:**
- `README.md` - New usage examples and migration notice
- `metadata.json` - Version bump to 2.0.0

## Breaking Changes

### Removed Parameters
- All flat `controller_*` parameters (20+ parameters)
- `controller_manage_rebuild` - No longer needed
- `controller_manage_alarm` - No longer needed

### New Parameters
- `controller_defaults` - Hash of default controller settings
- `controller_overrides` - Hash of per-controller overrides
- `vd_defaults` - Hash of default VD settings
- `vd_overrides` - Hash of per-VD overrides

### Kept Parameters (unchanged)
- `configure_settings` - Master kill switch
- `sync_time_to_controllers` - Time sync boolean
- `controller_use_utc` - UTC vs local time
- All install-related parameters

## Implementation Details

### Custom Type Design

All custom types follow consistent patterns:
1. Use facts to determine storcli/perccli binary path
2. Read current state via JSON where possible
3. Only change if needed (idempotent)
4. Append `nolog` to suppress logging
5. Proper error handling and logging

### Resource Naming Conventions

- Controller settings: `controller_id:setting_name` (e.g., `0:autorebuild`)
- VD settings: `controller_id/vd_id:setting_name` (e.g., `0/0:wrcache`)
- Patrol read: `controller_id`
- Consistency check: `controller_id`

### Hash Merging Strategy

1. Start with `controller_defaults`
2. Merge with `controller_overrides[controller_id]` if exists
3. Create resources only for keys present in merged hash
4. Same pattern for VD settings

## Migration Path

Users upgrading from v1.x need to:

1. Convert flat parameters to Hash structure
2. Remove `controller_manage_*` parameters
3. Test with `--noop` first
4. Review generated catalog

See `MIGRATION.md` for detailed instructions and examples.

## Testing

All tests have been updated to reflect the new architecture:
- Tests verify custom type creation
- Tests verify per-controller overrides work
- Tests verify pick-and-choose behavior
- Tests verify VD settings management

## Constraints Met

✅ No references to trunet/puppet-storcli issues  
✅ Uses existing `$facts['megaraid']['storcli']` for binary detection  
✅ All commands append `nolog`  
✅ `storcli::install` unchanged  
✅ API-breaking version bump to 2.0.0  
✅ Custom types for all major setting groups  
✅ Per-controller override support  
✅ VD cache settings support  
✅ Private classes with `assert_private()`  

## Files Changed

**New Files:**
- lib/puppet/type/megaraid_*.rb (4 files)
- lib/puppet/provider/megaraid_*/storcli.rb (4 files)
- manifests/configure/*.pp (4 files)
- spec/unit/puppet/type/megaraid_*_spec.rb (4 files)
- MIGRATION.md
- CHANGELOG.md updates

**Modified Files:**
- manifests/init.pp - New Hash-based parameters
- manifests/configure.pp - Now orchestrator only
- data/common.yaml - Hash structure
- metadata.json - Version bump
- README.md - New examples
- spec/classes/*.rb (2 files)

## Commits

1. Initial plan
2. Create custom Puppet types and providers for MegaRAID management
3. Refactor manifests to use Hash-based parameters and private classes
4. Rewrite tests for new Hash-based architecture and add type unit tests
5. Add CHANGELOG and migration guide for v2.0 release
6. Update README with v2.0 Hash-based configuration examples

## Next Steps

For users adopting v2.0:
1. Review MIGRATION.md
2. Update Hiera data
3. Test in development environment
4. Deploy to production

## Benefits

**For Users:**
- Per-controller configuration flexibility
- VD cache policy management
- Cleaner, more maintainable configuration
- Pick-and-choose setting management

**For Code Quality:**
- Proper Puppet types vs exec resources
- Better error handling
- Improved idempotency
- Cleaner catalog output
- Modular, testable architecture
