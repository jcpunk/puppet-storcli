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
end
