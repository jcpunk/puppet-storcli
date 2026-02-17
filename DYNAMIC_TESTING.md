# Dynamic Fixture Testing Guide

## Overview

The test suite in `spec/unit/facter/megaraid_spec.rb` automatically discovers and tests all fixture directories without requiring manual updates. This document explains how the dynamic testing works and how to add new fixtures.

## How It Works

### 1. Automatic Discovery

The test suite automatically scans the `spec/fixtures/` directory for subdirectories containing valid fixture files:

```ruby
fixture_dirs = Dir.glob('spec/fixtures/*/').select do |name|
  File.directory?("spec/fixtures/#{name}") && 
  File.exist?("spec/fixtures/#{name}/storcli_call_show.json")
end
```

### 2. Fixture Validation

For each discovered directory, the tests:
- Parse the `storcli_call_show.json` to extract controller metadata
- Build a mapping of which virtual drives belong to which controllers
- Look for optional fixture files (patrol read, consistency check, VD details)

### 3. Test Generation

For each valid fixture directory, the test suite automatically generates a complete test context with:
- Hardware detection tests
- Controller count validation
- Metadata parsing verification  
- Conditional tests based on available fixtures

## Adding New Fixtures

### Quick Method

1. Run the collection script on your host:
   ```bash
   sudo ./scripts/collect_fixtures.sh
   ```

2. Copy the generated directory to `spec/fixtures/`:
   ```bash
   cp -r /tmp/megaraid_fixtures/<model>/ spec/fixtures/<model>/
   ```

3. Run tests - no code changes needed:
   ```bash
   rake spec:unit
   ```

The tests will automatically detect and test your new fixtures!

### Manual Method

If collecting manually, ensure your fixture directory contains:

**Required:**
- `storcli_call_show.json` - Main controller information

**Optional (but recommended):**
- `storcli_call_show_patrolread.json` - Patrol read settings
- `storcli_call_show_cc.json` - Consistency check settings
- `storcli_call_show_vdisk<N>.json` - Per-VD cache settings

### Directory Structure Example

```
spec/fixtures/
├── 3108/                                    # Fixture set #1
│   ├── storcli_call_show.json
│   ├── storcli_call_show_patrolread.json
│   ├── storcli_call_show_cc.json
│   ├── storcli_call_show_vdisk0.json
│   └── storcli_call_show_vdisk234.json
├── 9560/                                    # Fixture set #2
│   ├── storcli_call_show.json
│   ├── storcli_call_show_patrolread.json
│   ├── storcli_call_show_cc.json
│   ├── storcli_call_show_vdisk238.json
│   └── storcli_call_show_vdisk239.json
├── H730/                                    # NEW: Auto-detected
│   ├── storcli_call_show.json
│   ├── storcli_call_show_patrolread.json
│   ├── storcli_call_show_cc.json
│   └── storcli_call_show_vdisk0.json
└── perccli_call_show_fail.json              # Special case fixture
```

## What Gets Tested

For each fixture directory, the tests validate:

### Basic Tests (Always Run)
- ✅ Hardware is detected (`present? == true`)
- ✅ Storcli binary is found
- ✅ Correct number of controllers detected
- ✅ Controller metadata (product_name) is present and non-empty

### Conditional Tests (Based on Available Fixtures)
- ✅ Patrol read settings (if `storcli_call_show_patrolread.json` exists)
- ✅ Consistency check settings (if `storcli_call_show_cc.json` exists)
- ✅ Virtual drive information (if `storcli_call_show_vdisk*.json` exist)

## Test Output Example

```
megaraid
  no module present
    should eq false
  module present, no storcli
    should eq true
  module present, storcli present with 3108 fixtures
    should detect megaraid hardware
    should detect 3 controller(s)
    should parse controller metadata correctly
    should parse patrol read settings
    should parse consistency check settings
    should parse virtual drive information
  module present, storcli present with 9560 fixtures
    should detect megaraid hardware
    should detect 1 controller(s)
    should parse controller metadata correctly
    should parse patrol read settings
    should parse consistency check settings
    should parse virtual drive information
  module present, storcli present with H730 fixtures  ← NEW
    should detect megaraid hardware
    should detect 2 controller(s)
    should parse controller metadata correctly
    should parse patrol read settings
    should parse consistency check settings
    should parse virtual drive information
```

## Benefits

### For Contributors
- ✅ **No test code changes needed** - Just add fixtures and run
- ✅ **Consistent validation** - All fixtures tested the same way
- ✅ **Fast feedback** - Immediately see if fixtures are valid

### For Maintainers
- ✅ **Better coverage** - More controller types automatically tested
- ✅ **Less maintenance** - No hardcoded test cases to update
- ✅ **Quality assurance** - Fixtures are validated on commit

### For Users
- ✅ **Confidence** - Their hardware type is tested
- ✅ **Easy contribution** - Low barrier to add fixtures
- ✅ **Visibility** - Can see test results for their controller model

## Troubleshooting

### Fixture Not Detected

**Symptom:** New fixture directory doesn't generate tests

**Solutions:**
1. Ensure directory is directly under `spec/fixtures/`
2. Verify `storcli_call_show.json` exists and is valid JSON
3. Check file permissions (must be readable)
4. Run `ls spec/fixtures/*/storcli_call_show.json` to verify

### VD Tests Not Running

**Symptom:** Virtual drive tests are skipped

**Solutions:**
1. Ensure VD fixtures follow naming: `storcli_call_show_vdisk<N>.json`
2. Verify VD numbers in filenames match VDs in `storcli_call_show.json`
3. Check that `VD LIST` exists in controller response data

### Patrol Read/CC Tests Not Running

**Symptom:** Patrol read or consistency check tests are skipped

**Solutions:**
1. Add `storcli_call_show_patrolread.json` for patrol read tests
2. Add `storcli_call_show_cc.json` for consistency check tests
3. These are optional - tests only run if fixtures exist

## Advanced Usage

### Testing Specific Fixtures Only

```bash
# Run tests for just one fixture set by filtering
rspec spec/unit/facter/megaraid_spec.rb -e "3108 fixtures"
```

### Validating New Fixtures Before Commit

```bash
# Quick syntax check
ruby -c spec/fixtures/NEW_MODEL/storcli_call_show.json

# Validate JSON
cat spec/fixtures/NEW_MODEL/storcli_call_show.json | jq . > /dev/null

# Run tests
rake spec:unit
```

### Debugging Fixture Issues

```ruby
# Add to test file temporarily to see what's discovered:
puts "Found fixture dirs: #{fixture_dirs.inspect}"
```

## Contributing Fixtures

When contributing new fixtures:

1. **Use real hardware** - Fixtures should come from actual systems
2. **Include all files** - Provide patrol read, CC, and VD fixtures when available
3. **Test first** - Run tests locally before committing
4. **Diverse hardware** - Aim for different models, vendors, firmware versions
5. **Document source** - In PR, note controller model and firmware version

## Related Documentation

- [FIXTURE_COLLECTION_GUIDE.md](FIXTURE_COLLECTION_GUIDE.md) - How to collect fixtures
- [FIXTURE_QUICKREF.md](FIXTURE_QUICKREF.md) - Quick reference for commands
- [FIXTURE_TEST_TEMPLATE.md](FIXTURE_TEST_TEMPLATE.md) - Adding custom tests

## Summary

The dynamic fixture testing approach makes it **trivial** to add test coverage for new MegaRAID controller types. Just collect the fixtures and drop them in `spec/fixtures/` - the test suite handles the rest!

This enables:
- **Community contributions** - Easy for users to add their hardware
- **Comprehensive coverage** - Test against real-world diversity
- **Regression protection** - Ensure code works across all tested hardware
- **Future compatibility** - New controllers tested as they're added
