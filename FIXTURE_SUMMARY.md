# Summary: Fixture Data Collection for 5 Hosts

## Quick Start

You asked for commands to run on 5 different hosts to generate JSON fixture data. Here's everything you need:

### The Simplest Way

On each of your 5 hosts, run:

```bash
# Copy the script to each host
scp scripts/collect_fixtures.sh user@host:/tmp/

# On each host, run as root:
sudo /tmp/collect_fixtures.sh
```

The script will:
1. Auto-detect your storcli/perccli binary
2. Auto-detect your controller model
3. Collect all necessary JSON files
4. Validate the output
5. Save to `spec/fixtures/<model>/`

### Manual Commands (If You Prefer)

On each host, replace `<MODEL>` with a short identifier (e.g., `3108`, `Dell_PERC_H730`):

```bash
STORCLI=storcli64  # or perccli64 for Dell
MODEL=3108         # choose appropriate identifier
mkdir -p spec/fixtures/$MODEL

# Required commands (run all 4):
$STORCLI /call show J nolog > spec/fixtures/$MODEL/storcli_call_show.json
$STORCLI /call show patrolread J nolog > spec/fixtures/$MODEL/storcli_call_show_patrolread.json
$STORCLI /call show cc J nolog > spec/fixtures/$MODEL/storcli_call_show_cc.json

# For each virtual disk (example for VD 0):
$STORCLI /c0/v0 show all J nolog > spec/fixtures/$MODEL/storcli_call_show_vdisk0.json
```

## Choosing Your 5 Hosts for Best Coverage

Pick hosts with different characteristics:

| Host # | Purpose | Characteristics | Example Model |
|--------|---------|-----------------|---------------|
| 1 | Baseline | Standard LSI/Avago, single controller | AVAGO 3108 MegaRAID |
| 2 | Dell variant | Dell PERC controller (uses perccli) | Dell PERC H730P |
| 3 | Multi-controller | 2+ controllers, various VDs | LSI 9560 + 3008-IR |
| 4 | Legacy | Older hardware/firmware | LSI 9260 or 3008-IR |
| 5 | Advanced | Different cache policies, RAID 6/60 | Any with WB/WT/AWB configs |

## What Files You'll Get

For each host, you'll have a directory like:

```
spec/fixtures/3108/
├── storcli_call_show.json              (main controller info)
├── storcli_call_show_patrolread.json   (patrol read settings)
├── storcli_call_show_cc.json           (consistency check settings)
└── storcli_call_show_vdisk0.json       (per-VD cache policies)
```

## After Collection

1. **Copy to repo:** Transfer all `spec/fixtures/*` directories to the repository

2. **Add tests:** Use the template in `FIXTURE_TEST_TEMPLATE.md` to add test cases

3. **Validate:** Run tests with `bundle exec rspec spec/unit/facter/megaraid_spec.rb`

4. **Commit:** Push the new fixtures and test cases

## Important Notes

✅ **Always use the `J nolog` flags** - Without `J` you get text instead of JSON  
✅ **Run as root** - storcli/perccli commands require root privileges  
✅ **Collect all VDs** - Don't forget to collect data for each virtual disk  
✅ **Use unique model IDs** - Each host should have a different directory name  

## Documents Available

- **FIXTURE_COLLECTION_GUIDE.md** - Complete detailed guide (10,000+ words)
- **FIXTURE_QUICKREF.md** - Quick reference card
- **FIXTURE_TEST_TEMPLATE.md** - How to add tests for your fixtures
- **scripts/collect_fixtures.sh** - Automated collection script

## Example Session

Here's what running the script looks like:

```
$ sudo ./scripts/collect_fixtures.sh
No storcli binary specified, attempting to auto-detect...
Found: /usr/sbin/storcli64
No controller model specified, attempting to auto-detect...
Detected: AVAGO 3108 MegaRAID
Using model identifier: 3108

========================================
Collecting Fixtures
========================================
Binary:     /usr/sbin/storcli64
Model:      3108
Output dir: spec/fixtures/3108
========================================

Collecting main controller info... OK
Collecting patrol read info... OK
Collecting consistency check info... OK

Detecting controllers and virtual disks...
Found 2 controller(s)

Checking controller 0 for virtual disks...
Collecting VD 0 on controller 0... OK

Checking controller 1 for virtual disks...
Collecting VD 0 on controller 1... OK
Collecting VD 234 on controller 1... OK

========================================
Collection Complete!
========================================

Files created in: spec/fixtures/3108
total 284K
-rw-r--r-- 1 root root  45K storcli_call_show.json
-rw-r--r-- 1 root root 1.2K storcli_call_show_patrolread.json
-rw-r--r-- 1 root root  987 storcli_call_show_cc.json
-rw-r--r-- 1 root root 234K storcli_call_show_vdisk0.json
-rw-r--r-- 1 root root 234K storcli_call_show_vdisk234.json
```

## Need Help?

- See `FIXTURE_COLLECTION_GUIDE.md` for comprehensive documentation
- See `FIXTURE_QUICKREF.md` for quick reference
- See `FIXTURE_TEST_TEMPLATE.md` for adding test cases
- Run `./scripts/collect_fixtures.sh --help` (if implemented)

Good luck with your fixture collection! 🎉
