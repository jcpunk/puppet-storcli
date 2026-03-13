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
        it { is_expected.not_to contain_exec('test: Enable consistency check mode=conc on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable consistency check on MegaRAID controller /c0') }
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
        it { is_expected.to contain_exec('test: Disable consistency check on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable consistency check mode=off on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Set consistency check delay=10 on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Set consistency check rate=11% on MegaRAID controller /c0') }
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
        it { is_expected.not_to contain_exec('test: Disable consistency check on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Enable consistency check mode=seq on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Set consistency check delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Set consistency check rate=11% on MegaRAID controller /c0') }
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
        it { is_expected.not_to contain_exec('test: Disable consistency check on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Enable consistency check mode=conc on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Set consistency check delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Set consistency check rate=11% on MegaRAID controller /c0') }
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
        it { is_expected.to contain_exec('all_cc: Enable consistency check mode=conc on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('all_cc: Enable consistency check mode=conc on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('all_cc: Set consistency check delay=672 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('all_cc: Set consistency check delay=672 on MegaRAID controller /c1') }
      end

      context 'mode=conc with minimal settings (sub-settings undef)' do
        let(:title) { 'minimal' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, mode: 'conc' } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('minimal: Enable consistency check mode=conc on MegaRAID controller /c0') }
        # delay and rate should not be managed
        it { is_expected.not_to contain_exec('minimal: Set consistency check delay= on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('minimal: Set consistency check rate=% on MegaRAID controller /c0') }
      end
    end
  end
end
