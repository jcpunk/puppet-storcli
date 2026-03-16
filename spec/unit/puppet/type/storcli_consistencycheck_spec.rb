# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/storcli_consistencycheck'

describe Puppet::Type.type(:storcli_consistencycheck) do
  describe 'namevar derivation of controller' do
    it 'derives controller 0 from title /c0' do
      resource = described_class.new(name: '/c0', mode: 'conc')
      expect(resource[:controller]).to eq(0)
    end

    it 'derives controller 1 from title /c1' do
      resource = described_class.new(name: '/c1', mode: 'seq')
      expect(resource[:controller]).to eq(1)
    end

    it "defaults to 'all' when title does not match /c<ID>" do
      resource = described_class.new(name: 'fleet_cc', mode: 'conc')
      expect(resource[:controller]).to eq('all')
    end

    it "derives 'all' from title /call" do
      resource = described_class.new(name: '/call', mode: 'off')
      expect(resource[:controller]).to eq('all')
    end

    it 'allows explicit controller to override title derivation' do
      resource = described_class.new(name: '/c0', controller: 1, mode: 'conc')
      expect(resource[:controller]).to eq(1)
    end
  end

  describe 'storcli_cmd default from fact' do
    it 'uses the storcli_tool from the matching controller in the fact' do
      allow(Facter).to receive(:value).with(:storcli).and_return(
        'present' => true,
        'controllers' => {
          0 => { 'storcli_tool' => '/opt/MegaRAID/storcli/storcli64' },
        },
      )
      resource = described_class.new(name: '/c0', mode: 'conc')
      expect(resource[:storcli_cmd]).to eq('/opt/MegaRAID/storcli/storcli64')
    end

    it 'uses the storcli_tool from the first controller when controller is all' do
      allow(Facter).to receive(:value).with(:storcli).and_return(
        'present' => true,
        'controllers' => {
          0 => { 'storcli_tool' => '/usr/sbin/perccli64' },
        },
      )
      resource = described_class.new(name: 'fleet_cc', mode: 'conc')
      expect(resource[:storcli_cmd]).to eq('/usr/sbin/perccli64')
    end

    it 'falls back to /usr/local/sbin/storcli when fact is nil' do
      allow(Facter).to receive(:value).with(:storcli).and_return(nil)
      resource = described_class.new(name: '/c0', mode: 'conc')
      expect(resource[:storcli_cmd]).to eq('/usr/local/sbin/storcli')
    end

    it 'allows explicit storcli_cmd to override the fact' do
      allow(Facter).to receive(:value).with(:storcli).and_return(
        'present' => true,
        'controllers' => {
          0 => { 'storcli_tool' => '/opt/MegaRAID/storcli/storcli64' },
        },
      )
      resource = described_class.new(name: '/c0', mode: 'conc', storcli_cmd: '/usr/local/bin/storcli')
      expect(resource[:storcli_cmd]).to eq('/usr/local/bin/storcli')
    end
  end

  describe 'autorequire' do
    it 'autorequires the storcli_packages package' do
      catalog = Puppet::Resource::Catalog.new
      pkg = Puppet::Type.type(:package).new(name: 'storcli_packages')
      resource = described_class.new(name: '/c0', mode: 'conc')
      catalog.add_resource pkg
      catalog.add_resource resource
      expect(resource.autorequire.map { |r| r.source.to_s }).to include('Package[storcli_packages]')
    end
  end
end
