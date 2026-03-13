# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/megaraid_patrolread'

describe Puppet::Type.type(:megaraid_patrolread) do
  let(:resource) do
    described_class.new(
      controller: 0,
      mode: 'auto',
      delay: 336,
      rate: 30
    )
  end

  it 'accepts a controller parameter' do
    expect(resource[:controller]).to eq(0)
  end

  it 'accepts a mode parameter' do
    expect(resource[:mode]).to eq('auto')
  end

  it 'accepts a delay parameter' do
    expect(resource[:delay]).to eq(336)
  end

  it 'accepts a rate parameter' do
    expect(resource[:rate]).to eq(30)
  end

  it 'accepts includessds parameter' do
    res = described_class.new(
      controller: 0,
      mode: 'auto',
      includessds: true
    )
    expect(res[:includessds]).to eq('on')
  end

  it 'accepts uncfgareas parameter' do
    res = described_class.new(
      controller: 0,
      mode: 'auto',
      uncfgareas: false
    )
    expect(res[:uncfgareas]).to eq('off')
  end
end
