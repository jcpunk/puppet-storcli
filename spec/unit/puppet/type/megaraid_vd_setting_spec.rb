# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/megaraid_vd_setting'

describe Puppet::Type.type(:megaraid_vd_setting) do
  let(:resource) do
    described_class.new(
      name: '0/0:wrcache',
      value: 'wt'
    )
  end

  it 'accepts a valid name' do
    expect(resource[:name]).to eq('0/0:wrcache')
  end

  it 'parses controller, vd, and setting from name' do
    expect(resource[:controller]).to eq(0)
    expect(resource[:vd]).to eq(0)
    expect(resource[:setting]).to eq('wrcache')
  end

  it 'accepts a value parameter' do
    expect(resource[:value]).to eq('wt')
  end

  it 'accepts "all" for vd' do
    res = described_class.new(
      name: '0/all:wrcache',
      value: 'wt'
    )
    expect(res[:vd]).to eq('all')
  end

  it 'raises error for invalid name format' do
    expect {
      described_class.new(
        name: 'invalid_name',
        value: 'wt'
      )
    }.to raise_error(Puppet::ResourceError, /Name must be in format/)
  end

  it 'validates wrcache values' do
    expect {
      described_class.new(
        name: '0/0:wrcache',
        value: 'invalid'
      )
    }.to raise_error(Puppet::ResourceError, /wrcache must be one of/)
  end
end
