# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/storcli_vd'

describe Puppet::Type.type(:storcli_vd) do
  describe 'namevar derivation of controller' do
    it 'derives controller 0 from title /c0/v1' do
      resource = described_class.new(name: '/c0/v1')
      expect(resource[:controller]).to eq(0)
    end

    it 'derives controller 1 from title /c1/v0' do
      resource = described_class.new(name: '/c1/v0')
      expect(resource[:controller]).to eq(1)
    end

    it "defaults to 'all' when title does not match /c<ID>" do
      resource = described_class.new(name: 'fleet_policy')
      expect(resource[:controller]).to eq('all')
    end

    it "derives 'all' from title /call/vall" do
      resource = described_class.new(name: '/call/vall')
      expect(resource[:controller]).to eq('all')
    end
  end

  describe 'namevar derivation of virtual_disk' do
    it 'derives virtual_disk 1 from title /c0/v1' do
      resource = described_class.new(name: '/c0/v1')
      expect(resource[:virtual_disk]).to eq(1)
    end

    it 'derives virtual_disk 0 from title /c1/v0' do
      resource = described_class.new(name: '/c1/v0')
      expect(resource[:virtual_disk]).to eq(0)
    end

    it "defaults to 'all' when title does not match /v<ID>" do
      resource = described_class.new(name: 'fleet_policy')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it "derives 'all' from title /c0/vall" do
      resource = described_class.new(name: '/c0/vall')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it "derives 'all' from title /call/vall" do
      resource = described_class.new(name: '/call/vall')
      expect(resource[:virtual_disk]).to eq('all')
    end
  end

  describe 'combined controller and virtual_disk derivation' do
    it 'derives both from /c2/v3' do
      resource = described_class.new(name: '/c2/v3')
      expect(resource[:controller]).to eq(2)
      expect(resource[:virtual_disk]).to eq(3)
    end

    it 'derives controller all and virtual_disk all from /call/vall' do
      resource = described_class.new(name: '/call/vall')
      expect(resource[:controller]).to eq('all')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it 'defaults both to all for a generic title' do
      resource = described_class.new(name: 'fleet_settings')
      expect(resource[:controller]).to eq('all')
      expect(resource[:virtual_disk]).to eq('all')
    end

    it 'allows explicit overrides for both' do
      resource = described_class.new(name: '/c0/v1', controller: 2, virtual_disk: 3)
      expect(resource[:controller]).to eq(2)
      expect(resource[:virtual_disk]).to eq(3)
    end
  end
end
