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
      expect(fact.value['present?']).to eq(false)
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

      expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli64').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('storcli').and_return(nil)
      expect(Facter::Util::Resolution).to receive(:which).with('/opt/MegaRAID/storcli/storcli').and_return(nil)

      expect(Facter::Util::Resolution).not_to receive(:exec)
    end

    it do
      expect(fact.value['present?']).to eq(true)
      expect(fact.value['storcli']).to eq(nil)
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers']).to eq({})
    end
  end

  # Helper method to setup fixture-based testing
  def self.setup_fixture_test(fixture_name)
    fixture_dir = "spec/fixtures/#{fixture_name}"
    return unless File.directory?(fixture_dir)
    
    # Load main controller data
    main_fixture = File.join(fixture_dir, 'storcli_call_show.json')
    return unless File.exist?(main_fixture)
    
    controller_data = JSON.parse(File.read(main_fixture))
    controllers = controller_data['Controllers'] || []
    
    # Build VD mapping: which VDs belong to which controllers
    vd_mapping = {}
    controllers.each_with_index do |ctrl, ctrl_idx|
      vd_list = ctrl.dig('Response Data', 'VD LIST') || []
      vd_list.each do |vd|
        dg_vd = vd['DG/VD']
        next unless dg_vd
        vd_num = dg_vd.split('/').last
        vd_mapping["#{ctrl_idx}/#{vd_num}"] = true
      end
    end
    
    context "module present, storcli present with #{fixture_name} fixtures" do
      before :each do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
        expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

        expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return('/example/path')
        expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli64')
        expect(Facter::Util::Resolution).not_to receive(:which).with('storcli')
        expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli')

        # Main fixture
        expect(Facter::Util::Resolution).to receive(:exec)
          .with('/example/path /call show J nolog')
          .and_return(File.read("#{fixture_dir}/storcli_call_show.json"))
        
        # Patrol read fixture if exists
        patrolread_fixture = "#{fixture_dir}/storcli_call_show_patrolread.json"
        if File.exist?(patrolread_fixture)
          expect(Facter::Util::Resolution).to receive(:exec)
            .with('/example/path /call show patrolread J nolog')
            .and_return(File.read(patrolread_fixture))
        end
        
        # Consistency check fixture if exists
        cc_fixture = "#{fixture_dir}/storcli_call_show_cc.json"
        if File.exist?(cc_fixture)
          expect(Facter::Util::Resolution).to receive(:exec)
            .with('/example/path /call show cc J nolog')
            .and_return(File.read(cc_fixture))
        end
        
        # VD fixtures
        Dir.glob("#{fixture_dir}/storcli_call_show_vdisk*.json").each do |vdisk_file|
          if File.basename(vdisk_file) =~ /storcli_call_show_vdisk(\d+)\.json/
            vd_num = Regexp.last_match(1)
            # Find which controller(s) this VD belongs to
            vd_mapping.each_key do |key|
              ctrl_idx, key_vd_num = key.split('/')
              if key_vd_num == vd_num
                expect(Facter::Util::Resolution).to receive(:exec)
                  .with("/example/path /c#{ctrl_idx}/v#{vd_num} show all J nolog")
                  .and_return(File.read(vdisk_file))
              end
            end
          end
        end
      end

      it 'should detect megaraid hardware' do
        expect(fact.value['present?']).to eq(true)
        expect(fact.value['storcli']).to eq('/example/path')
      end
      
      it "should detect #{controllers.length} controller(s)" do
        expect(fact.value['number_of_controllers']).to eq(controllers.length)
        expect(fact.value['controllers'].count).to eq(controllers.length)
      end
      
      it 'should parse controller metadata correctly' do
        fact.value['controllers'].each do |ctrl_id, ctrl_data|
          expect(ctrl_data).to have_key('product_name')
          expect(ctrl_data['product_name']).to be_a(String)
          expect(ctrl_data['product_name']).not_to be_empty
        end
      end
      
      if File.exist?("#{fixture_dir}/storcli_call_show_patrolread.json")
        it 'should parse patrol read settings' do
          fact.value['controllers'].each do |ctrl_id, ctrl_data|
            expect(ctrl_data).to have_key('patrol_read')
            expect(ctrl_data['patrol_read']).to be_a(Hash)
          end
        end
      end
      
      if File.exist?("#{fixture_dir}/storcli_call_show_cc.json")
        it 'should parse consistency check settings' do
          fact.value['controllers'].each do |ctrl_id, ctrl_data|
            expect(ctrl_data).to have_key('consistency_check')
            expect(ctrl_data['consistency_check']).to be_a(Hash)
          end
        end
      end
      
      unless vd_mapping.empty?
        it 'should parse virtual drive information' do
          # At least one controller should have VDs
          has_vds = fact.value['controllers'].any? { |_, ctrl_data| !ctrl_data['virtual_drives'].empty? }
          expect(has_vds).to eq(true)
        end
      end
    end
  end

  # Dynamically discover and test all fixture directories
  fixture_dirs = Dir.glob('spec/fixtures/*/').map { |d| File.basename(d) }.select do |name|
    File.directory?("spec/fixtures/#{name}") && 
    File.exist?("spec/fixtures/#{name}/storcli_call_show.json")
  end
  
  fixture_dirs.each do |fixture_name|
    setup_fixture_test(fixture_name)
  end

  context 'module present, storcli present, card unsupported' do
    before :each do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/mpt3sas').and_return(true)
      expect(Dir).to receive(:exist?).with('/sys/bus/pci/drivers/megaraid_sas').and_return(true)

      expect(Facter::Util::Resolution).to receive(:which).with('storcli64').and_return('/example/path')
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli64')
      expect(Facter::Util::Resolution).not_to receive(:which).with('storcli')
      expect(Facter::Util::Resolution).not_to receive(:which).with('/opt/MegaRAID/storcli/storcli')

      expect(Facter::Util::Resolution).to receive(:exec).with('/example/path /call show J nolog').and_return(File.read('spec/fixtures/storcli_call_show_fail.json'))
      expect(Facter::Util::Resolution).not_to receive(:exec).with('/example/path /call show patrolread J nolog')
      expect(Facter::Util::Resolution).not_to receive(:exec).with('/example/path /call show cc J nolog')
    end

    it do
      expect(fact.value['present?']).to eq(true)
      expect(fact.value['storcli']).to eq('/example/path')
      expect(fact.value['number_of_controllers']).to eq(0)
      expect(fact.value['controllers'].count).to eq(0)
    end
  end
end
