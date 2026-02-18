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

      expect(Facter::Util::Resolution).not_to receive(:which)
      expect(Facter::Util::Resolution).not_to receive(:exec)
    end

    it do
      expect(fact.value['present']).to eq(false)
      expect(fact.value['storcli']).to eq(nil)
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  context 'module present, no storcli' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
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
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  context 'module present, storcli present, card unsupported' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

      # Mock DMI for non-Dell
      allow(Facter).to receive(:value).with(:dmi).and_return({ 'manufacturer' => 'Supermicro' })

      expect(Facter::Util::Resolution).to receive(:which).with('storcli2').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli2').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return('/example/path')
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli64')
      expect(Facter::Util::Resolution).not_to receive(:which).with('storcli')
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli')

      expect(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show J nolog').and_return(File.read('spec/fixtures/storcli_call_show_fail.json'))
      expect(Facter::Util::Resolution).not_to receive(:exec).with('/example/path /call show patrolread J nolog')
      expect(Facter::Util::Resolution).not_to receive(:exec).with('/example/path /call show cc J nolog')
    end

    it do
      expect(fact.value['present']).to eq(true)
      expect(fact.value['storcli']).to eq('/example/path')
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers'].count).to eq(0)
    end
  end

  # Dynamically discover and test all fixture directories
  Dir.glob('spec/fixtures/*/storcli_call_show.json').sort.each do |fixture_file|
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
          expect(ctrl).to have_key('drive_groups')
          expect(ctrl).to have_key('physical_drive_count')
          expect(ctrl).to have_key('virtual_drives')
          expect(ctrl).to have_key('patrol_read')
          expect(ctrl).to have_key('consistency_check')

          # Verify patrol_read structure
          pr = ctrl['patrol_read']
          expect(pr).to be_a(Hash)
          expect(pr).to have_key('mode')
          expect(pr).to have_key('next_start_time')
          # If not Un-supported, should have additional keys
          if pr['mode'] != 'Un-supported'
            expect(pr).to have_key('execution_delay') if pr.key?('execution_delay')
            expect(pr).to have_key('on_ssd') if pr.key?('on_ssd')
          end

          # Verify consistency_check structure
          cc = ctrl['consistency_check']
          expect(cc).to be_a(Hash)
          expect(cc).to have_key('operation_mode')
          expect(cc).to have_key('next_start_time')
          # If not Un-supported, should have additional keys
          if cc['operation_mode'] != 'Un-supported'
            expect(cc).to have_key('execution_delay') if cc.key?('execution_delay')
          end

          # Verify virtual_drives structure
          vd = ctrl['virtual_drives']
          expect(vd).to be_a(Hash)

          vd.each_value do |vd_info|
            expect(vd_info).to have_key('type')
            expect(vd_info).to have_key('state')
            expect(vd_info).to have_key('strip_size')
            expect(vd_info).to have_key('size')
            expect(vd_info).to have_key('write_cache')
            expect(vd_info).to have_key('read_cache')
            expect(vd_info).to have_key('io_policy')
            expect(vd_info).to have_key('physical_drive_cache')
            expect(vd_info).to have_key('name')
            expect(vd_info).to have_key('encryption')
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

          # Check virtual_drives use snake_case
          ctrl['virtual_drives'].each_value do |vd_info|
            expect(vd_info.keys).not_to include('Type', 'State', 'Strip Size', 'Write Cache', 'Read Cache', 'IO Policy', 'Physical Drive Cache', 'Name', 'Encryption')
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
    end
  end
end
