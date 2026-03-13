# frozen_string_literal: true

require 'spec_helper'

describe 'storcli::patrolread' do
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
        let(:params) { { controller: 0, mode: 'auto', storcli_cmd: :undef } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Enable patrolread mode=auto on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable patrolread on MegaRAID controller /c0') }
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
            includessds: false,
            uncfgareas: false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable patrolread mode=off on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'mode=auto with all sub-settings' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            mode: 'auto',
            delay: 10,
            rate: 11,
            includessds: false,
            uncfgareas: false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Enable patrolread mode=auto on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'mode=manual (delay not applied)' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            mode: 'manual',
            delay: 10,
            rate: 11,
            includessds: false,
            uncfgareas: false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Disable patrolread on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Enable patrolread mode=manual on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'mode=auto with includessds=true' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            mode: 'auto',
            includessds: true,
            uncfgareas: false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Enable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable patrolread on SSDs on MegaRAID controller /c0') }
      end

      context 'mode=auto with uncfgareas=true' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            mode: 'auto',
            includessds: false,
            uncfgareas: true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Enable patrolread on unconfigured areas on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context "with controller => 'all'" do
        let(:title) { 'all_pr' }
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
        let(:params) { { controller: 'all', mode: 'auto', rate: 30 } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('all_pr: Enable patrolread mode=auto on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('all_pr: Enable patrolread mode=auto on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('all_pr: Set patrolread rate=30% on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('all_pr: Set patrolread rate=30% on MegaRAID controller /c1') }
      end

      context 'mode=auto with minimal settings (sub-settings undef)' do
        let(:title) { 'minimal' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, mode: 'auto' } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('minimal: Enable patrolread mode=auto on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('minimal: Set patrolread delay= on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('minimal: Set patrolread rate=% on MegaRAID controller /c0') }
      end
    end
  end
end
