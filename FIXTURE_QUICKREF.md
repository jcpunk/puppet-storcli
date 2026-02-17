# Quick Reference: Fixture Collection for 5 Hosts

## TL;DR - Commands to Run on Each Host

### Option 1: Use the Automated Script (Recommended)

```bash
# On each host, run:
sudo ./scripts/collect_fixtures.sh

# Or specify binary and model explicitly:
sudo ./scripts/collect_fixtures.sh storcli64 3108
sudo ./scripts/collect_fixtures.sh perccli64 Dell_PERC_H730
```

### Option 2: Manual Commands

On each host, run these commands (replace `storcli64` with your binary):

```bash
# Set up
STORCLI_BIN=storcli64  # or perccli64
MODEL="3108"           # change per host

# Create directory
mkdir -p spec/fixtures/$MODEL

# Collect data
$STORCLI_BIN /call show J nolog > spec/fixtures/$MODEL/storcli_call_show.json
$STORCLI_BIN /call show patrolread J nolog > spec/fixtures/$MODEL/storcli_call_show_patrolread.json
$STORCLI_BIN /call show cc J nolog > spec/fixtures/$MODEL/storcli_call_show_cc.json

# For each VD (example for VD 0):
$STORCLI_BIN /c0/v0 show all J nolog > spec/fixtures/$MODEL/storcli_call_show_vdisk0.json
```

## Suggested Host Configuration for Good Coverage

### Host 1: "Standard LSI"
- **Model ID:** `3108` or `9560`
- **Purpose:** Baseline LSI/Avago controller
- **Characteristics:** Single controller, 1-2 VDs, basic configuration

### Host 2: "Dell PERC"
- **Model ID:** `Dell_PERC_H730` (or H330, H740, etc.)
- **Purpose:** Test Dell perccli variant
- **Binary:** Use `perccli64` instead of `storcli64`
- **Characteristics:** Dell-branded controller

### Host 3: "Multi-Controller"
- **Model ID:** `MultiController` or specific model
- **Purpose:** Test multiple controllers
- **Characteristics:** 2+ controllers, various VD IDs

### Host 4: "Legacy Hardware"
- **Model ID:** `3008` or `9260`
- **Purpose:** Older firmware/hardware compatibility
- **Characteristics:** Older controller model

### Host 5: "Advanced Config"
- **Model ID:** Same or different from above
- **Purpose:** Advanced cache policies and RAID levels
- **Characteristics:** 
  - Different cache settings (WB/WT/AWB)
  - RAID 6/60 configurations
  - Mixed VD configurations

## Directory Structure After Collection

```
spec/fixtures/
├── 3108/
│   ├── storcli_call_show.json
│   ├── storcli_call_show_patrolread.json
│   ├── storcli_call_show_cc.json
│   └── storcli_call_show_vdisk0.json
├── Dell_PERC_H730/
│   ├── storcli_call_show.json
│   ├── storcli_call_show_patrolread.json
│   ├── storcli_call_show_cc.json
│   └── storcli_call_show_vdisk0.json
├── 9560/
│   ├── storcli_call_show.json
│   ├── storcli_call_show_patrolread.json
│   ├── storcli_call_show_cc.json
│   ├── storcli_call_show_vdisk238.json
│   └── storcli_call_show_vdisk239.json
├── 3008/
│   └── ...
└── 9260/
    └── ...
```

## Validation

After collecting on all 5 hosts:

```bash
# Validate all JSON files
find spec/fixtures -name "*.json" -exec python3 -m json.tool {} \; > /dev/null

# Check for required files in each directory
for dir in spec/fixtures/*/; do
    echo "Checking $dir"
    [ -f "$dir/storcli_call_show.json" ] && echo "  ✓ Main controller info" || echo "  ✗ Missing main info"
    [ -f "$dir/storcli_call_show_patrolread.json" ] && echo "  ✓ Patrol read" || echo "  ✗ Missing patrol read"
    [ -f "$dir/storcli_call_show_cc.json" ] && echo "  ✓ Consistency check" || echo "  ✗ Missing CC"
    ls "$dir"storcli_call_show_vdisk*.json >/dev/null 2>&1 && echo "  ✓ VD info" || echo "  ⚠ No VD files"
done
```

## What Makes Good Coverage?

✅ **Different controller models** - 3108, 9560, PERC, 3008, etc.
✅ **Different binaries** - Both storcli and perccli
✅ **Multiple controllers** - At least one multi-controller system
✅ **Various VD IDs** - Not just VD 0, include 1, 2, 234, etc.
✅ **Different RAID levels** - RAID 0, 1, 5, 6, 10, 60
✅ **Different cache policies** - WT, WB, AWB combinations
✅ **Legacy hardware** - Older controllers and firmware

## Files Required Per Host

**Minimum (4 files):**
1. `storcli_call_show.json` - Main controller info
2. `storcli_call_show_patrolread.json` - PR settings
3. `storcli_call_show_cc.json` - CC settings
4. `storcli_call_show_vdisk0.json` - At least one VD

**Better (5+ files):**
- All of the above
- Additional VD files for each virtual disk
- Consider: `storcli_call_show_vdisk1.json`, `vdisk234.json`, etc.

## Common Pitfalls

❌ Forgetting the `J` flag → Gets text output instead of JSON
❌ Missing the `nolog` flag → Includes log messages that break JSON
❌ Not running as root → Permission denied
❌ Reusing same model ID for different hardware → Overwriting fixtures
❌ Not collecting VD-specific data → Missing cache policy tests

## After Collection

1. Copy all `spec/fixtures/*` directories to the repository
2. Update `spec/unit/facter/megaraid_spec.rb` with new test cases
3. Run tests: `bundle exec rake spec`
4. Commit and push

For detailed instructions, see: [FIXTURE_COLLECTION_GUIDE.md](FIXTURE_COLLECTION_GUIDE.md)
