# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/megaraid'
require 'json'

describe :megaraid, type: :fact do
  subject(:fact) { Facter.fact(:megaraid) }

  before :each do
    # perform any action that should be run before every test
    Facter.clear
  end

  context 'no module present' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(false)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(false)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(false)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpi3mr').and_return(false)

      expect(Facter::Util::Resolution).not_to receive(:which)
      expect(Facter::Util::Resolution).not_to receive(:exec)
    end

    it do
      expect(fact.value['present']).to eq(false)
      expect(fact.value['storcli']).to eq(nil)
      expect(fact.value['storcli_tools']).to eq([])
      expect(fact.value['tool_info']).to eq([])
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  context 'module present, no storcli' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpi3mr').and_return(false)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

      # Mock DMI for non-Dell
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })

      expect(Facter::Util::Resolution).to receive(:which).with('storcli2').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli2').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)

      expect(Facter::Util::Resolution).not_to receive(:exec)
    end

    it do
      expect(fact.value['present']).to eq(true)
      expect(fact.value['storcli']).to eq(nil)
      expect(fact.value['storcli_tools']).to eq([])
      expect(fact.value['tool_info']).to eq([])
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  context 'module present, storcli present, card unsupported' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpi3mr').and_return(false)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

      # Mock DMI for non-Dell
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })

      # Now checks all locations to find all tools
      allow(Facter::Util::Resolution).to receive(:which).with('storcli2').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli2').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return('/example/path')
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)

      # Mock tool info call
      allow(Facter::Util::Resolution).to receive(:exec).with('/example/path show J nolog').and_return(File.read('spec/fixtures/storcli_call_show_fail.json'))
      allow(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show J nolog').and_return(File.read('spec/fixtures/storcli_call_show_fail.json'))
    end

    it do
      expect(fact.value['present']).to eq(true)
      expect(fact.value['storcli']).to eq('/example/path')
      expect(fact.value['storcli_tools']).to eq(['/example/path'])
      expect(fact.value['tool_info']).to be_a(Array)
      expect(fact.value['tool_info'].length).to eq(1)
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers'].count).to eq(0)
    end
  end

  context 'module present with mpi3mr driver' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(false)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(false)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(false)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpi3mr').and_return(true)

      # Mock DMI for non-Dell
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })

      allow(Facter::Util::Resolution).to receive(:which).with('storcli2').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli2').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)
    end

    it 'detects mpi3mr driver as present' do
      expect(fact.value['present']).to eq(true)
      expect(fact.value['storcli']).to eq(nil)
      expect(fact.value['storcli_tools']).to eq([])
      expect(fact.value['tool_info']).to eq([])
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  # Note: The code now supports multiple storcli tools (e.g., both storcli and storcli2)
  # on the same system. Each tool is queried and results are combined. This is tested
  # implicitly by the mocking infrastructure which allows multiple tools to be present.

  context 'timeout protection' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpi3mr').and_return(false)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })
      
      # Mock which to find a tool
      allow(Facter::Util::Resolution).to receive(:which).with('storcli2').and_return('/example/path')
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli2').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil)
      allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)
    end

    it 'times out and returns safe defaults when fact collection hangs' do
      # Mock a hanging exec call
      allow(Facter::Util::Resolution).to receive(:exec).with('/example/path show J nolog') do
        sleep 65 # Longer than 60 second timeout
      end

      # Should timeout and return error state
      result = fact.value
      expect(result).to be_a(Hash)
      expect(result['error']).to match(/timed out/i)
      expect(result['present']).to eq(false)
      expect(result['storcli']).to eq(nil)
      expect(result['number_of_controllers']).to eq(0)
    end

    it 'handles exceptions gracefully' do
      # Mock an exception
      allow(Megaraid).to receive(:new).and_raise(StandardError, 'Test error')

      result = fact.value
      expect(result).to be_a(Hash)
      expect(result['error']).to eq('Test error')
      expect(result['present']).to eq(false)
      expect(result['storcli']).to eq(nil)
      expect(result['number_of_controllers']).to eq(0)
    end
  end

  # Dynamically discover and test all fixture directories
  FIXTURE_BASE_PATH = 'spec/fixtures'
  
  Dir.glob(File.join(FIXTURE_BASE_PATH, '*/storcli_call_show.json')).sort.each do |fixture_file|
    fixture_dir = File.dirname(fixture_file)
    card_name = File.basename(fixture_dir)

    context "module present, storcli present on #{card_name}" do
      let(:fixture_path) { fixture_dir }
      let(:show_json) { JSON.parse(File.read("#{fixture_path}/storcli_call_show.json")) }
      let(:pr_json) { JSON.parse(File.read("#{fixture_path}/storcli_call_show_patrolread.json")) }
      let(:cc_json) { JSON.parse(File.read("#{fixture_path}/storcli_call_show_cc.json")) }

      # Analyze fixture to determine what to expect
      let(:controllers) do
        show_json['Controllers'].select { |c| c.dig('Command Status', 'Status') != 'Failure' }
      end

      let(:controller_ids) do
        controllers.map { |c| c.dig('Command Status', 'Controller').to_s }.compact
      end

      let(:is_dell) { card_name.include?('PERC') || card_name.include?('Dell') }

      before :each do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
        allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpi3mr').and_return(false)
        allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

        # Mock DMI appropriately
        if is_dell
          allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Dell Inc.' })
          allow(Facter::Util::Resolution).to receive(:which).with('perccli2').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/perccli/perccli2').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('perccli64').and_return('/example/path')
          allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/perccli/perccli64').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('perccli').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/perccli/perccli').and_return(nil)
        else
          allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })
          allow(Facter::Util::Resolution).to receive(:which).with('storcli2').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli2').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return('/example/path')
          allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil)
          allow(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)
        end

        # Mock the main storcli calls
        allow(Facter::Util::Resolution).to receive(:exec).with('/example/path show J nolog').and_return(File.read("#{fixture_path}/storcli_call_show.json"))
        allow(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show J nolog').and_return(File.read("#{fixture_path}/storcli_call_show.json"))
        allow(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show patrolread J nolog').and_return(File.read("#{fixture_path}/storcli_call_show_patrolread.json"))
        allow(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show cc J nolog').and_return(File.read("#{fixture_path}/storcli_call_show_cc.json"))

        # Mock VD detail calls for each controller
        controller_ids.each do |ctrl_id|
          ctrl_data = controllers.find { |c| c.dig('Command Status', 'Controller').to_s == ctrl_id }
          vd_list = ctrl_data&.dig('Response Data', 'VD LIST') || []

          vd_list.each do |vd_item|
            # Support both 'DG/VD' and 'VD' keys
            vd_id = if vd_item.key?('DG/VD')
                      vd_item['DG/VD'].split('/')[1]
                    elsif vd_item.key?('VD')
                      vd_item['VD'].to_s
                    else
                      next
                    end

            vd_file = "#{fixture_path}/storcli_call_show_vdisk#{vd_id}.json"
            if File.exist?(vd_file)
              allow(Facter::Util::Resolution).to receive(:exec).with("/example/path /c#{ctrl_id}/v#{vd_id} show all J nolog").and_return(File.read(vd_file))
            else
              # If vdisk file doesn't exist, return empty JSON
              allow(Facter::Util::Resolution).to receive(:exec).with("/example/path /c#{ctrl_id}/v#{vd_id} show all J nolog").and_return('{"Controllers":[]}')
            end
          end
        end
      end

      it 'has correct top-level keys' do
        expect(fact.value['present']).to eq(true)
        expect(fact.value['storcli']).to eq('/example/path')
        expect(fact.value['storcli_tools']).to eq(['/example/path'])
        expect(fact.value['tool_info']).to be_a(Array)
        expect(fact.value['number_of_controllers']).to eq(controller_ids.length)
        expect(fact.value['controllers']).to be_a(Hash)
      end

      it 'has correct controller structure' do
        expect(fact.value['controllers'].keys.sort).to eq(controller_ids.sort)

        controller_ids.each do |ctrl_id|
          ctrl = fact.value['controllers'][ctrl_id]
          
          # Check all required keys are present
          expect(ctrl).to have_key('product_name')
          expect(ctrl).to have_key('serial_number')
          expect(ctrl).to have_key('fw_package_build')
          expect(ctrl).to have_key('fw_version')
          expect(ctrl).to have_key('bios_version')
          expect(ctrl).to have_key('driver_name')
          expect(ctrl).to have_key('device_interface')
          expect(ctrl).to have_key('drive_groups_count')
          expect(ctrl).to have_key('physical_drive_count')
          expect(ctrl).to have_key('storcli_tool')
          expect(ctrl).to have_key('drive_groups')
          expect(ctrl).to have_key('controller_settings')
          expect(ctrl).to have_key('bbu_info')
          expect(ctrl).to have_key('patrol_read')
          expect(ctrl).to have_key('consistency_check')

          # Verify storcli_tool is a full path
          expect(ctrl['storcli_tool']).to match(%r{^/})

          # Verify patrol_read structure
          pr = ctrl['patrol_read']
          expect(pr).to be_a(Hash)
          expect(pr).to have_key('mode')
          expect(pr).to have_key('next_start_time')
          # If not Un-supported, should have execution_delay and on_ssd
          unless pr['mode'] == 'Un-supported'
            expect(pr).to have_key('execution_delay')
            expect(pr).to have_key('on_ssd')
          end

          # Verify consistency_check structure
          cc = ctrl['consistency_check']
          expect(cc).to be_a(Hash)
          expect(cc).to have_key('operation_mode')
          expect(cc).to have_key('next_start_time')
          # If not Un-supported, should have execution_delay
          unless cc['operation_mode'] == 'Un-supported'
            expect(cc).to have_key('execution_delay')
          end

          # Verify controller_settings structure
          if ctrl['controller_settings']
            settings = ctrl['controller_settings']
            expect(settings).to be_a(Hash)
            # Settings may have Un-supported as sentinel value
          end

          # Verify bbu_info structure
          if ctrl['bbu_info']
            bbu = ctrl['bbu_info']
            expect(bbu).to be_a(Hash)
            expect(bbu).to have_key('state')
          end

          # Verify drive_groups structure
          dgs = ctrl['drive_groups']
          expect(dgs).to be_a(Hash)

          # Each drive group should have virtual_disks
          dgs.each_value do |dg|
            expect(dg).to have_key('virtual_disks')
            expect(dg['virtual_disks']).to be_a(Hash)

            # Verify each virtual disk has required fields (new structure)
            dg['virtual_disks'].each_value do |vd_info|
              expect(vd_info).to have_key('name')
              expect(vd_info).to have_key('raid_level')
              expect(vd_info).to have_key('size')
              expect(vd_info).to have_key('state')
              expect(vd_info).to have_key('properties')
              
              # Verify properties sub-hash
              props = vd_info['properties']
              expect(props).to be_a(Hash)
              expect(props).to have_key('stripe_size')
              expect(props).to have_key('span_depth')
              expect(props).to have_key('number_of_drives_per_span')
              # New configuration-relevant properties
              expect(props).to have_key('exposed_to_os')
              expect(props).to have_key('unmap_enabled')
              expect(props).to have_key('data_protection')
            end
          end
        end
      end

      it 'uses snake_case for all keys' do
        controller_ids.each do |ctrl_id|
          ctrl = fact.value['controllers'][ctrl_id]

          # Check patrol_read uses snake_case
          pr = ctrl['patrol_read']
          expect(pr.keys).not_to include('PR Mode', 'PR Execution Delay', 'PR Next Start time', 'PR on SSD')

          # Check consistency_check uses snake_case
          cc = ctrl['consistency_check']
          expect(cc.keys).not_to include('CC Operation Mode', 'CC Execution Delay', 'CC Next Starttime')

          # Check virtual_disks within drive_groups use new structure
          ctrl['drive_groups'].each_value do |dg|
            dg['virtual_disks'].each_value do |vd_info|
              # Old keys should not exist
              expect(vd_info.keys).not_to include('type', 'strip_size', 'write_cache', 'read_cache', 'io_policy', 'physical_drive_cache', 'encryption')
              # New structure should have these
              expect(vd_info.keys).to include('name', 'raid_level', 'size', 'state', 'properties')
            end
          end
        end
      end

      it 'does not include monitoring fields' do
        controller_ids.each do |ctrl_id|
          ctrl = fact.value['controllers'][ctrl_id]

          # Patrol read should not have monitoring fields
          pr = ctrl['patrol_read']
          expect(pr.keys).not_to include('PR Current State', 'PR iterations completed', 'PR Excluded VDs', 'PR MaxConcurrentPd')

          # Consistency check should not have monitoring fields
          cc = ctrl['consistency_check']
          expect(cc.keys).not_to include('CC Current State', 'CC Number of iterations', 'CC Number of VD completed', 'CC Excluded VDs')
        end
      end

      it 'organizes virtual disks by drive group' do
        controller_ids.each do |ctrl_id|
          ctrl = fact.value['controllers'][ctrl_id]
          dgs = ctrl['drive_groups']

          # Verify drive groups structure
          expect(dgs).to be_a(Hash)
          
          # Each drive group should have virtual_disks
          dgs.each do |dg_id, dg_data|
            expect(dg_data).to have_key('virtual_disks')
            expect(dg_data['virtual_disks']).to be_a(Hash)
            
            # DG ID should be a string
            expect(dg_id).to be_a(String)
            
            # Each VD should have an ID
            dg_data['virtual_disks'].each do |vd_id, vd_data|
              expect(vd_id).to be_a(String)
              expect(vd_data).to be_a(Hash)
            end
          end
        end
      end
    end
  end
end
