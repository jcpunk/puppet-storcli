# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/megaraid_consistency_check'

describe Puppet::Type.type(:megaraid_consistency_check) do
  let(:resource) do
    described_class.new(
      controller: 0,
      mode: 'conc',
      delay: 672,
      rate: 30
    )
  end

  it 'accepts a controller parameter' do
    expect(resource[:controller]).to eq(0)
  end

  it 'accepts a mode parameter' do
    expect(resource[:mode]).to eq('conc')
  end

  it 'accepts a delay parameter' do
    expect(resource[:delay]).to eq(672)
  end

  it 'accepts a rate parameter' do
    expect(resource[:rate]).to eq(30)
  end
end
