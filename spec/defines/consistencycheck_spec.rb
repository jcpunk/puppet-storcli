# frozen_string_literal: true

require 'spec_helper'

describe 'storcli::consistencycheck' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { "class { 'storcli': configure_settings => false }" }

      let(:default_facts) do
        os_facts.merge({
                         'storcli' => {
                           'present' => true,
                           'storcli_tool' => '/usr/local/sbin/storcli64',
                           'number_of_controllers' => 1,
                           'controllers' => {
                             0 => { 'storcli_tool' => '/usr/local/sbin/storcli64' },
                           },
                         },
                       })
      end

      context 'without storcli_cmd' do
        let(:title) { 'test' }
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'number_of_controllers' => 0,
                             'controllers' => {},
                           },
                         })
        end
        let(:params) { { controller: 0, mode: 'conc', storcli_cmd: :undef } }

        it { is_expected.to compile }
        it { is_expected.to have_storcli_consistencycheck_resource_count(0) }
      end

      context 'mode=off' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            mode: 'off',
            delay: 10,
            rate: 11,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_consistencycheck('test_c0').with(mode: 'off') }
      end

      context 'mode=seq' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            mode: 'seq',
            delay: 10,
            rate: 11,
          }
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_storcli_consistencycheck('test_c0').with(
            mode: 'seq',
            delay: 10,
            rate: 11,
          )
        }
      end

      context 'mode=conc' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            mode: 'conc',
            delay: 10,
            rate: 11,
          }
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_storcli_consistencycheck('test_c0').with(
            mode: 'conc',
            delay: 10,
            rate: 11,
          )
        }
      end

      context "with controller => 'all'" do
        let(:title) { 'all_cc' }
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => {
                               0 => { 'storcli_tool' => '/usr/local/sbin/storcli64' },
                               1 => { 'storcli_tool' => '/usr/local/sbin/storcli64' },
                             },
                           },
                         })
        end
        let(:params) { { controller: 'all', mode: 'conc', delay: 672, rate: 30 } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_consistencycheck('all_cc_c0').with(mode: 'conc', delay: 672) }
        it { is_expected.to contain_storcli_consistencycheck('all_cc_c1').with(mode: 'conc', delay: 672) }
      end

      context 'mode=conc with minimal settings (sub-settings undef)' do
        let(:title) { 'minimal' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, mode: 'conc' } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_consistencycheck('minimal_c0').with(mode: 'conc') }
        it { is_expected.to contain_storcli_consistencycheck('minimal_c0').without_delay }
        it { is_expected.to contain_storcli_consistencycheck('minimal_c0').without_rate }
      end
    end
  end
end
