# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/storcli_controller'

describe Puppet::Type.type(:storcli_controller) do
  describe 'namevar derivation of controller' do
    it 'derives controller 0 from title /c0' do
      resource = described_class.new(name: '/c0')
      expect(resource[:controller]).to eq(0)
    end

    it 'derives controller 1 from title /c1' do
      resource = described_class.new(name: '/c1')
      expect(resource[:controller]).to eq(1)
    end

    it 'derives controller 12 from title /c12' do
      resource = described_class.new(name: '/c12')
      expect(resource[:controller]).to eq(12)
    end

    it "defaults to 'all' when title does not match /c<ID>" do
      resource = described_class.new(name: 'fleet_settings')
      expect(resource[:controller]).to eq('all')
    end

    it "derives 'all' from title /call" do
      resource = described_class.new(name: '/call')
      expect(resource[:controller]).to eq('all')
    end

    it 'allows explicit controller to override title derivation' do
      resource = described_class.new(name: '/c0', controller: 1)
      expect(resource[:controller]).to eq(1)
    end

    it "allows explicit controller 'all' to override title" do
      resource = described_class.new(name: '/c0', controller: 'all')
      expect(resource[:controller]).to eq('all')
    end
  end
end
