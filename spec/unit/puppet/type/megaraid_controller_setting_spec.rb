# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/megaraid_controller_setting'

describe Puppet::Type.type(:megaraid_controller_setting) do
  let(:resource) do
    described_class.new(
      name: '0:autorebuild',
      value: 'on'
    )
  end

  it 'accepts a valid name' do
    expect(resource[:name]).to eq('0:autorebuild')
  end

  it 'parses controller and setting from name' do
    expect(resource[:controller]).to eq(0)
    expect(resource[:setting]).to eq('autorebuild')
  end

  it 'accepts a value parameter' do
    expect(resource[:value]).to eq('on')
  end

  it 'raises error for invalid name format' do
    expect {
      described_class.new(
        name: 'invalid_name',
        value: 'on'
      )
    }.to raise_error(Puppet::ResourceError, /Name must be in format/)
  end
end
