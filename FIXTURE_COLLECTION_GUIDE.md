# Fixture Data Collection Guide for puppet-storcli

This guide provides instructions for collecting JSON fixture data from MegaRAID controllers to improve test coverage.

## Overview

The test suite uses JSON fixture files that capture real controller output. These fixtures are organized by controller model/type to ensure comprehensive test coverage across different hardware configurations.

## Directory Structure

Fixture files are organized as follows:

```
spec/fixtures/
├── <controller_model>/        # One directory per controller type
│   ├── storcli_call_show.json                    # Main controller info
│   ├── storcli_call_show_patrolread.json         # Patrol read settings
│   ├── storcli_call_show_cc.json                 # Consistency check settings
│   ├── storcli_call_show_vdisk<N>.json           # Per-virtual disk info
│   └── ...
└── perccli_call_show_fail.json                   # Failure case (Dell systems)
```

**Examples of controller model directories:**
- `3108` - AVAGO 3108 MegaRAID
- `9560` - LSI 9560 series
- `9361` - LSI 9361 series
- `3008` - LSI 3008-IR
- `Dell_PERC` - Dell PERC controllers (using perccli)

## Commands to Run on Each Host

### Step 1: Identify Your Controller

First, determine your controller model to create the appropriate directory:

```bash
# Find the storcli or perccli binary
which storcli64 || which storcli || which perccli64 || which perccli

# Set the binary path (adjust based on your system)
STORCLI_BIN=$(which storcli64 || which storcli || which perccli64 || which perccli)

# Get controller info to determine the model
$STORCLI_BIN /call show J nolog | grep -i "Product Name"
```

### Step 2: Create Directory Name

Based on the controller model, choose a short, descriptive directory name. Examples:
- AVAGO 3108 MegaRAID → `3108`
- LSI 9560 → `9560`
- LSI 9361-8i → `9361`
- Dell PERC H730P → `Dell_PERC_H730P`

### Step 3: Collect Controller Data

Run these commands and save the output to the corresponding files:

#### A. Main Controller Information
```bash
# Command to run:
$STORCLI_BIN /call show J nolog

# Save to:
spec/fixtures/<controller_model>/storcli_call_show.json

# Example:
storcli64 /call show J nolog > spec/fixtures/3108/storcli_call_show.json
```

This file contains:
- Controller product name, serial number, firmware version
- Virtual drive list (VD LIST)
- Physical drive topology
- Controller capabilities

#### B. Patrol Read Information
```bash
# Command to run:
$STORCLI_BIN /call show patrolread J nolog

# Save to:
spec/fixtures/<controller_model>/storcli_call_show_patrolread.json

# Example:
storcli64 /call show patrolread J nolog > spec/fixtures/3108/storcli_call_show_patrolread.json
```

This file contains:
- PR Mode (auto/manual/off)
- PR Execution Delay
- PR on SSD setting
- PR Next Start time

#### C. Consistency Check Information
```bash
# Command to run:
$STORCLI_BIN /call show cc J nolog

# Save to:
spec/fixtures/<controller_model>/storcli_call_show_cc.json

# Example:
storcli64 /call show cc J nolog > spec/fixtures/3108/storcli_call_show_cc.json
```

This file contains:
- CC Operation Mode (off/seq/conc)
- CC Execution Delay
- CC Rate
- CC Next Starttime

#### D. Virtual Disk Information

For **each virtual disk** on **each controller**, run:

```bash
# Command to run:
$STORCLI_BIN /c<controller_id>/v<vd_id> show all J nolog

# Save to:
spec/fixtures/<controller_model>/storcli_call_show_vdisk<vd_id>.json

# Examples:
storcli64 /c0/v0 show all J nolog > spec/fixtures/3108/storcli_call_show_vdisk0.json
storcli64 /c0/v1 show all J nolog > spec/fixtures/3108/storcli_call_show_vdisk1.json
storcli64 /c1/v234 show all J nolog > spec/fixtures/3108/storcli_call_show_vdisk234.json
```

This file contains:
- VD Properties (Name, Type, State)
- Cache settings (Write Cache, Read Cache, IO Policy)
- Physical Drive Cache policy
- Strip Size, Encryption status

**Note:** The virtual disk ID in the filename should match the actual VD ID, not necessarily be sequential. For example, `vdisk234.json` for VD 234.

### Step 4: Identify Controllers and Virtual Disks

To determine which commands to run, first inspect your system:

```bash
# List all controllers
$STORCLI_BIN /call show J nolog | grep -A2 "Controller"

# For each controller, list virtual disks
$STORCLI_BIN /c0 show J nolog | grep "DG/VD"
$STORCLI_BIN /c1 show J nolog | grep "DG/VD"
# etc...
```

## Complete Example: Collecting Data from One Host

Here's a complete example for a host with:
- Controller 0: AVAGO 3108 with VD 0
- Controller 1: AVAGO 3108 with VD 0 and VD 234

```bash
# Set up
STORCLI_BIN=/usr/sbin/storcli64
FIXTURE_DIR=spec/fixtures/3108
mkdir -p $FIXTURE_DIR

# Collect main controller data
$STORCLI_BIN /call show J nolog > $FIXTURE_DIR/storcli_call_show.json

# Collect patrol read data
$STORCLI_BIN /call show patrolread J nolog > $FIXTURE_DIR/storcli_call_show_patrolread.json

# Collect consistency check data
$STORCLI_BIN /call show cc J nolog > $FIXTURE_DIR/storcli_call_show_cc.json

# Collect virtual disk data
$STORCLI_BIN /c0/v0 show all J nolog > $FIXTURE_DIR/storcli_call_show_vdisk0.json
$STORCLI_BIN /c1/v0 show all J nolog > $FIXTURE_DIR/storcli_call_show_vdisk0.json  # same file reused
$STORCLI_BIN /c1/v234 show all J nolog > $FIXTURE_DIR/storcli_call_show_vdisk234.json
```

## Planning Your 5 Hosts

To maximize test coverage, choose hosts with different characteristics:

### Host 1: Standard LSI/Avago Controller
- **Goal:** Test typical LSI/Avago hardware
- **Characteristics:** Single controller, multiple VDs
- **Example:** AVAGO 3108 MegaRAID

### Host 2: Dell PERC Controller
- **Goal:** Test Dell-specific perccli variant
- **Characteristics:** Dell-branded controller
- **Example:** Dell PERC H730P or H330
- **Note:** Use `perccli` or `perccli64` instead of `storcli`

### Host 3: Multiple Controllers
- **Goal:** Test multi-controller systems
- **Characteristics:** 2+ controllers, various VD configurations
- **Example:** System with RAID + HBA controllers

### Host 4: Legacy/Older Hardware
- **Goal:** Test backward compatibility
- **Characteristics:** Older firmware versions, older controller models
- **Example:** LSI 3008-IR or older 9260 series

### Host 5: Advanced Features
- **Goal:** Test advanced cache policies and configurations
- **Characteristics:** Various cache settings (WB/WT/AWB), different RAID levels
- **Example:** System with mixed cache policies, RAID 6/60 configurations

## File Naming Conventions

1. **Directory name:** Short identifier for controller model (e.g., `3108`, `9560`, `Dell_PERC_H730P`)

2. **Main files:** Always use these exact names:
   - `storcli_call_show.json`
   - `storcli_call_show_patrolread.json`
   - `storcli_call_show_cc.json`

3. **VD files:** Use format `storcli_call_show_vdisk<ID>.json` where `<ID>` is the actual VD number
   - Examples: `vdisk0.json`, `vdisk1.json`, `vdisk234.json`

4. **Reuse VD files:** If multiple controllers have VDs with identical configurations, you can reuse the same fixture file (as shown in the test suite)

## Validation

After collecting fixtures, validate them:

```bash
# Check JSON is valid
for file in spec/fixtures/<controller_model>/*.json; do
  echo "Validating $file"
  python3 -m json.tool "$file" > /dev/null || echo "ERROR in $file"
done

# Verify required fields exist
grep -q "Product Name" spec/fixtures/<controller_model>/storcli_call_show.json
grep -q "PR Mode" spec/fixtures/<controller_model>/storcli_call_show_patrolread.json
grep -q "CC Operation Mode" spec/fixtures/<controller_model>/storcli_call_show_cc.json
```

## Testing Your Fixtures

After adding new fixtures, update the test file `spec/unit/facter/megaraid_spec.rb` to include your new controller model. Follow the existing pattern for the 3108 and 9560 examples.

## Troubleshooting

### Command Not Found
If `storcli64` or `storcli` is not in your PATH:
```bash
# Try these locations:
/opt/MegaRAID/storcli/storcli64
/opt/MegaRAID/storcli/storcli
/opt/MegaRAID/perccli/perccli64
/opt/MegaRAID/perccli/perccli
```

### Permission Denied
Commands require root privileges:
```bash
sudo storcli64 /call show J nolog
```

### No Controllers Found
Verify the RAID kernel module is loaded:
```bash
lsmod | grep -E 'megaraid|mpt3sas'
ls /sys/bus/pci/drivers/megaraid_sas/
```

### JSON Parse Errors
Ensure you're using the `J` flag for JSON output and `nolog` to suppress log messages:
```bash
# Correct:
storcli64 /call show J nolog

# Incorrect (missing J):
storcli64 /call show nolog
```

## Quick Reference: All Commands for One Host

```bash
#!/bin/bash
# Save as: collect_fixtures.sh

STORCLI_BIN=${1:-storcli64}
CONTROLLER_MODEL=${2:-unknown}
FIXTURE_DIR="spec/fixtures/$CONTROLLER_MODEL"

echo "Collecting fixtures for $CONTROLLER_MODEL using $STORCLI_BIN"
mkdir -p "$FIXTURE_DIR"

# Main controller info
echo "Collecting main controller info..."
$STORCLI_BIN /call show J nolog > "$FIXTURE_DIR/storcli_call_show.json"

# Patrol read
echo "Collecting patrol read info..."
$STORCLI_BIN /call show patrolread J nolog > "$FIXTURE_DIR/storcli_call_show_patrolread.json"

# Consistency check
echo "Collecting consistency check info..."
$STORCLI_BIN /call show cc J nolog > "$FIXTURE_DIR/storcli_call_show_cc.json"

# Parse VD list and collect each VD
echo "Collecting virtual disk info..."
# This requires jq or manual inspection to determine VD IDs
# Example for known VDs:
# $STORCLI_BIN /c0/v0 show all J nolog > "$FIXTURE_DIR/storcli_call_show_vdisk0.json"

echo "Done! Fixtures saved to $FIXTURE_DIR"
echo "Remember to collect VD-specific data for each virtual disk"
```

Usage:
```bash
chmod +x collect_fixtures.sh
sudo ./collect_fixtures.sh storcli64 3108
sudo ./collect_fixtures.sh perccli64 Dell_PERC_H730P
```

## Summary Checklist

For each of your 5 hosts:

- [ ] Determine controller model and create directory name
- [ ] Run `storcli /call show J nolog` → save to `storcli_call_show.json`
- [ ] Run `storcli /call show patrolread J nolog` → save to `storcli_call_show_patrolread.json`
- [ ] Run `storcli /call show cc J nolog` → save to `storcli_call_show_cc.json`
- [ ] For each VD: Run `storcli /c#/v# show all J nolog` → save to `storcli_call_show_vdisk#.json`
- [ ] Validate all JSON files
- [ ] Add test cases to `spec/unit/facter/megaraid_spec.rb`
- [ ] Run tests: `bundle exec rake spec`

Good luck with your fixture collection!
