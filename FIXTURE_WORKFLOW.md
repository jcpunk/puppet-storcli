# Fixture Collection Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     START: You Have 5 Hosts                      │
│                    (with different controllers)                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: Read FIXTURE_SUMMARY.md                                │
│  ├─ Understand what's needed                                    │
│  ├─ Choose diverse hosts for coverage                           │
│  └─ Review quick start commands                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: On Each Host - Collect Fixtures                        │
│                                                                  │
│  Option A (Automated - Recommended):                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. Copy script to host:                                  │  │
│  │    scp scripts/collect_fixtures.sh user@host:/tmp/       │  │
│  │                                                           │  │
│  │ 2. Run on host:                                          │  │
│  │    sudo /tmp/collect_fixtures.sh                         │  │
│  │                                                           │  │
│  │ 3. Script automatically:                                 │  │
│  │    ✓ Finds storcli/perccli binary                        │  │
│  │    ✓ Detects controller model                            │  │
│  │    ✓ Creates spec/fixtures/<model>/ directory            │  │
│  │    ✓ Collects all JSON files                             │  │
│  │    ✓ Validates JSON output                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Option B (Manual):                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ STORCLI=storcli64; MODEL=3108                            │  │
│  │ mkdir -p spec/fixtures/$MODEL                            │  │
│  │                                                           │  │
│  │ $STORCLI /call show J nolog >                            │  │
│  │   spec/fixtures/$MODEL/storcli_call_show.json            │  │
│  │                                                           │  │
│  │ $STORCLI /call show patrolread J nolog >                 │  │
│  │   spec/fixtures/$MODEL/storcli_call_show_patrolread.json │  │
│  │                                                           │  │
│  │ $STORCLI /call show cc J nolog >                         │  │
│  │   spec/fixtures/$MODEL/storcli_call_show_cc.json         │  │
│  │                                                           │  │
│  │ # For each VD:                                           │  │
│  │ $STORCLI /c0/v0 show all J nolog >                       │  │
│  │   spec/fixtures/$MODEL/storcli_call_show_vdisk0.json     │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: Validate Output                                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ # Check JSON is valid:                                   │  │
│  │ for f in spec/fixtures/<model>/*.json; do                │  │
│  │   python3 -m json.tool "$f" > /dev/null                  │  │
│  │ done                                                      │  │
│  │                                                           │  │
│  │ # Verify required files exist:                           │  │
│  │ ls spec/fixtures/<model>/storcli_call_show.json          │  │
│  │ ls spec/fixtures/<model>/storcli_call_show_patrolread.json│  │
│  │ ls spec/fixtures/<model>/storcli_call_show_cc.json       │  │
│  │ ls spec/fixtures/<model>/storcli_call_show_vdisk*.json   │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: Repeat for All 5 Hosts                                 │
│  ┌────────────┬────────────┬────────────┬────────────┬────────┐ │
│  │  Host 1    │  Host 2    │  Host 3    │  Host 4    │ Host 5 │ │
│  │  (LSI)     │  (Dell)    │  (Multi)   │  (Legacy)  │ (Adv)  │ │
│  ├────────────┼────────────┼────────────┼────────────┼────────┤ │
│  │ 3108/      │ PERC_H730/ │ 9560/      │ 3008/      │ 9361/  │ │
│  │ ├─show.json│ ├─show.json│ ├─show.json│ ├─show.json│ ├─...  │ │
│  │ ├─pr.json  │ ├─pr.json  │ ├─pr.json  │ ├─pr.json  │ └─...  │ │
│  │ ├─cc.json  │ ├─cc.json  │ ├─cc.json  │ ├─cc.json  │        │ │
│  │ └─vd0.json │ └─vd0.json │ ├─vd238.json│ └─vd0.json │        │ │
│  │            │            │ └─vd239.json│            │        │ │
│  └────────────┴────────────┴────────────┴────────────┴────────┘ │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 5: Transfer to Repository                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ # Copy all fixture directories:                          │  │
│  │ scp -r spec/fixtures/* user@repo-host:/path/to/repo/     │  │
│  │                                                           │  │
│  │ # Or use git from one of the hosts:                      │  │
│  │ git add spec/fixtures/*                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 6: Add Test Cases                                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. Open spec/unit/facter/megaraid_spec.rb                │  │
│  │                                                           │  │
│  │ 2. Use FIXTURE_TEST_TEMPLATE.md for each model:          │  │
│  │    - Copy template code                                  │  │
│  │    - Replace <MODEL> with your directory name            │  │
│  │    - Update controller count, product names              │  │
│  │    - Add VD expectations                                 │  │
│  │                                                           │  │
│  │ 3. Extract values from your fixtures:                    │  │
│  │    grep "Product Name" spec/fixtures/<model>/...         │  │
│  │    grep "Cache" spec/fixtures/<model>/...                │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 7: Run Tests                                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ # Test just your new fixtures:                           │  │
│  │ bundle exec rspec spec/unit/facter/megaraid_spec.rb      │  │
│  │                                                           │  │
│  │ # Run all tests:                                         │  │
│  │ bundle exec rake spec                                    │  │
│  │                                                           │  │
│  │ # Validate and lint:                                     │  │
│  │ pdk validate                                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 8: Commit and Push                                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ git add spec/fixtures/*                                  │  │
│  │ git add spec/unit/facter/megaraid_spec.rb                │  │
│  │ git commit -m "Add fixtures from 5 diverse hosts"        │  │
│  │ git push                                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ✓ SUCCESS!                                    │
│     You've Contributed Comprehensive Test Coverage!             │
└─────────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════
                        QUICK REFERENCE
═══════════════════════════════════════════════════════════════════

Documents to Reference:
  • FIXTURE_SUMMARY.md         ← Start here
  • FIXTURE_QUICKREF.md         ← Commands cheat sheet
  • FIXTURE_COLLECTION_GUIDE.md ← Complete reference
  • FIXTURE_TEST_TEMPLATE.md    ← Test case templates

Script to Use:
  • scripts/collect_fixtures.sh ← Run on each host

Time Estimate:
  • 15 minutes per host (with automated script)
  • 75 minutes total for all 5 hosts
  • Plus 30-60 minutes to add test cases

═══════════════════════════════════════════════════════════════════
```

## Common Scenarios

### Scenario 1: All 5 Hosts Are Similar
If your hosts have similar controllers, consider:
- Different firmware versions
- Different number of VDs
- Different cache configurations
- Different RAID levels

This still provides value even if hardware is similar!

### Scenario 2: Can't Access a Dell PERC
That's okay! Focus on:
- Different LSI models (3108, 9560, 9361, 9260, 3008)
- HBA vs RAID mode controllers
- Single vs multi-controller systems

### Scenario 3: Virtual Machines/Simulated Hardware
- Use whatever controllers are available
- Even limited coverage is better than none
- Document any limitations in test comments

### Scenario 4: Time Constrained
Minimum viable contribution:
1. Run automated script on 3 hosts (different models if possible)
2. Add basic test cases for each
3. Document what's covered vs. what's missing

## Tips for Success

✓ **Use the automated script** - Saves time and reduces errors  
✓ **Choose diverse hosts** - Different models = better coverage  
✓ **Validate before leaving host** - Ensure JSON is valid  
✓ **Document special cases** - Note any unusual configurations  
✓ **Start simple** - Even 1-2 new fixtures help!  

## Getting Help

- Review existing fixtures in `spec/fixtures/3108/` and `spec/fixtures/9560/`
- Check existing tests in `spec/unit/facter/megaraid_spec.rb`
- All documentation files have troubleshooting sections
- The automated script has built-in validation

Good luck! Your fixture contributions will help ensure this module works across diverse hardware! 🎉
