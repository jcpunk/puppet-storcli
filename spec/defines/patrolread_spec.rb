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
        it { is_expected.to have_storcli_patrolread_resource_count(0) }
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
        it { is_expected.to contain_storcli_patrolread('test_c0').with(mode: 'off') }
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
        it {
          is_expected.to contain_storcli_patrolread('test_c0').with(
            mode: 'auto',
            delay: 10,
            rate: 11,
            includessds: false,
            uncfgareas: false,
          )
        }
      end

      context 'mode=manual (delay not applied by native type)' do
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
        it {
          is_expected.to contain_storcli_patrolread('test_c0').with(
            mode: 'manual',
            rate: 11,
            includessds: false,
            uncfgareas: false,
          )
        }
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
        it { is_expected.to contain_storcli_patrolread('test_c0').with(includessds: true) }
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
        it { is_expected.to contain_storcli_patrolread('test_c0').with(uncfgareas: true) }
      end

      context "with controller => 'all'" do
        let(:title) { 'all_pr' }
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
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
        it { is_expected.to contain_storcli_patrolread('all_pr_c0').with(mode: 'auto', rate: 30) }
        it { is_expected.to contain_storcli_patrolread('all_pr_c1').with(mode: 'auto', rate: 30) }
      end

      context 'mode=auto with minimal settings (sub-settings undef)' do
        let(:title) { 'minimal' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, mode: 'auto' } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_patrolread('minimal_c0').with(mode: 'auto') }
        it { is_expected.to contain_storcli_patrolread('minimal_c0').without_delay }
        it { is_expected.to contain_storcli_patrolread('minimal_c0').without_rate }
      end
    end
  end
end
