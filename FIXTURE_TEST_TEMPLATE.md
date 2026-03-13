# Template for Adding New Fixture Test Cases

When you've collected fixtures from a new host, follow this template to add test cases to `spec/unit/facter/megaraid_spec.rb`.

## Step 1: Identify Your Test Parameters

From your fixture collection, note:
- **Controller Model ID:** The directory name (e.g., `3108`, `Dell_PERC_H730`)
- **Number of Controllers:** Count from fixture data
- **Controller IDs:** Usually 0, 1, 2, etc.
- **Virtual Disks:** Which VDs exist on which controllers
- **Product Names:** From the fixture JSON

## Step 2: Add Test Context

Insert this code block into `spec/unit/facter/megaraid_spec.rb`, following the existing pattern:

```ruby
  context 'module present, storcli present on YOUR_MODEL_HERE' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

      # Adjust binary name if using perccli
      expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return('/example/path')
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli64')
      expect(Facter::Util::Resolution).not_to receive(:which).with('storcli')
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli')

      # Main controller data
      expect(Facter::Util::Resolution).to receive(:exec)
        .with('/example/path /call show J nolog')
        .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show.json'))
      
      # Patrol read data
      expect(Facter::Util::Resolution).to receive(:exec)
        .with('/example/path /call show patrolread J nolog')
        .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_patrolread.json'))
      
      # Consistency check data
      expect(Facter::Util::Resolution).to receive(:exec)
        .with('/example/path /call show cc J nolog')
        .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_cc.json'))
      
      # Virtual disk data - ADD ONE FOR EACH VD
      # Example for controller 0, VD 0:
      expect(Facter::Util::Resolution).to receive(:exec)
        .with('/example/path /c0/v0 show all J nolog')
        .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_vdisk0.json'))
      
      # Example for controller 0, VD 1:
      # expect(Facter::Util::Resolution).to receive(:exec)
      #   .with('/example/path /c0/v1 show all J nolog')
      #   .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_vdisk1.json'))
      
      # Example for controller 1, VD 234:
      # expect(Facter::Util::Resolution).to receive(:exec)
      #   .with('/example/path /c1/v234 show all J nolog')
      #   .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_vdisk234.json'))
    end

    it do
      expect(fact.value['present?']).to eq(true)
      expect(fact.value['storcli']).to eq('/example/path')
      expect(fact.value['number_of_controllers']).to eq(NUMBER_OF_CONTROLLERS)  # e.g., 1, 2, 3
    end
    
    it 'controllers structure' do
      expect(fact.value['controllers'].count).to eq(NUMBER_OF_CONTROLLERS)

      # Test product name for each controller
      expect(fact.value.fetch('controllers')['0']['product_name']).to eq('PRODUCT_NAME_HERE')
      # Add more if you have multiple controllers:
      # expect(fact.value.fetch('controllers')['1']['product_name']).to eq('PRODUCT_NAME_HERE')

      # Test patrol read settings
      # Adjust based on your actual data
      expect(fact.value.fetch('controllers')['0']['patrol_read']['PR Mode']).to eq('Auto')
      # or eq('Un-supported') for controllers without PR support

      # Test consistency check settings
      expect(fact.value.fetch('controllers')['0']['consistency_check']['CC Operation Mode']).to eq('Concurrent')
      # or eq('Un-supported') for controllers without CC support

      # Test virtual drives
      # Adjust VD IDs and expected values based on your fixtures
      expect(fact.value.fetch('controllers')['0']['virtual_drives']).to include(
        '0' => hash_including(
          'Name' => 'storage1',  # or whatever name is in your fixture
          'Type' => 'RAID6',     # RAID level from your fixture
          'State' => 'Optimal',  # or Optl
          'Write Cache' => 'wt', # wt, wb, or awb
          'Read Cache' => 'ra',  # ra or nora
          'IO Policy' => 'direct', # direct or cached
          'Physical Drive Cache' => 'default' # on, off, or default
        )
      )
    end
  end
```

## Step 3: Customize for Your Hardware

### For Dell PERC Controllers

If using `perccli` instead of `storcli`, adjust the binary detection:

```ruby
expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return(nil)
expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
expect(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil)
expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)
expect(Facter::Util::Resolution).to receive(:which).with('perccli64').and_return('/example/perccli')
```

### For Multi-Controller Systems

Add expectations for each controller's VDs:

```ruby
# Controller 0, VD 0
expect(Facter::Util::Resolution).to receive(:exec)
  .with('/example/path /c0/v0 show all J nolog')
  .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_vdisk0.json'))

# Controller 1, VD 0
expect(Facter::Util::Resolution).to receive(:exec)
  .with('/example/path /c1/v0 show all J nolog')
  .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_vdisk0.json'))

# Controller 1, VD 234
expect(Facter::Util::Resolution).to receive(:exec)
  .with('/example/path /c1/v234 show all J nolog')
  .and_return(File.read('spec/fixtures/YOUR_MODEL/storcli_call_show_vdisk234.json'))
```

### For Controllers Without PR/CC Support

Some controllers (like HBA mode) don't support patrol read or consistency check:

```ruby
it 'unsupported features' do
  expect(fact.value.fetch('controllers')['0']['patrol_read']['PR Mode']).to eq('Un-supported')
  expect(fact.value.fetch('controllers')['0']['consistency_check']['CC Operation Mode']).to eq('Un-supported')
end
```

## Step 4: Extract Values from Your Fixtures

To get the correct values for your tests:

```bash
# Get product name
grep -i "Product Name" spec/fixtures/YOUR_MODEL/storcli_call_show.json

# Get VD info
grep -A5 "VD LIST" spec/fixtures/YOUR_MODEL/storcli_call_show.json

# Get cache settings
grep -E "Cache|IO Policy" spec/fixtures/YOUR_MODEL/storcli_call_show_vdisk0.json
```

Or use Python:

```python
import json

# Load fixture
with open('spec/fixtures/YOUR_MODEL/storcli_call_show.json') as f:
    data = json.load(f)

# Extract product name
for controller in data['Controllers']:
    print(controller['Response Data']['Product Name'])

# Extract VD list
for controller in data['Controllers']:
    vd_list = controller['Response Data'].get('VD LIST', [])
    for vd in vd_list:
        print(f"VD: {vd['DG/VD']}, Type: {vd['TYPE']}, State: {vd['State']}")
```

## Complete Example

See the existing test cases for `3108` and `9560` in `spec/unit/facter/megaraid_spec.rb` for complete working examples.

## Running Your Tests

After adding the test case:

```bash
# Run just the megaraid tests
bundle exec rspec spec/unit/facter/megaraid_spec.rb

# Run all tests
bundle exec rake spec
```

## Common Issues

1. **Missing VD fixture files:** Ensure you have `.and_return()` for every VD shown in the main fixture
2. **Wrong product names:** Must match exactly what's in the fixture JSON
3. **Cache policy mismatches:** Extract exact values from VD fixture JSON
4. **Controller count wrong:** Count unique controller IDs from main fixture

## Checklist

- [ ] Created fixture directory with model name
- [ ] Collected all 4 required JSON files (main, PR, CC, at least one VD)
- [ ] Added test context to `megaraid_spec.rb`
- [ ] Configured all VD expectations
- [ ] Set correct product names
- [ ] Set correct controller count
- [ ] Verified cache policy values match fixtures
- [ ] Tests pass: `bundle exec rspec spec/unit/facter/megaraid_spec.rb`
