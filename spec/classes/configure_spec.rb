# frozen_string_literal: true

require 'spec_helper'

describe 'storcli::configure' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'without storcli' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => nil, 'controllers' => {} } }) }

        it { is_expected.to compile }
        it { is_expected.to contain_class('storcli::configure::controller') }
        it { is_expected.to contain_class('storcli::configure::patrolread') }
        it { is_expected.to contain_class('storcli::configure::consistencycheck') }
        it { is_expected.to contain_class('storcli::configure::virtual_drives') }
      end

      context 'with storcli, no management' do
        let(:facts) { os_facts.merge({ 'megaraid' => { 'present?' => true, 'storcli' => 'storcli64', 'controllers' => {} } }) }
        let(:params) do
          {
            'configure_settings' => false,
            'controller_defaults' => {},
            'controller_overrides' => {},
            'vd_defaults' => {},
            'vd_overrides' => {},
          }
        end

        it { is_expected.to compile }
        it { is_expected.not_to contain_megaraid_controller_setting('0:autorebuild') }
      end

      context 'with storcli and management - defaults from Hash' do
        let(:facts) do
          os_facts.merge({
            'megaraid' => {
              'present?' => true,
              'storcli' => 'storcli64',
              'controllers' => {
                0 => { 'virtual_drives' => {} },
                1 => { 'virtual_drives' => {} },
              },
            },
          })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_defaults' => {
              'autorebuild' => true,
              'rebuildrate' => 60,
              'perfmode' => 0,
              'ncq' => true,
              'cacheflushinterval' => 4,
              'bootwithpinnedcache' => false,
              'alarm' => true,
              'smartpollinterval' => 60,
              'patrolread_mode' => 'auto',
              'patrolread_delay' => 336,
              'patrolread_rate' => 30,
              'patrolread_includessds' => false,
              'patrolread_uncfgareas' => false,
              'consistencycheck_mode' => 'conc',
              'consistencycheck_delay' => 672,
              'consistencycheck_rate' => 30,
            },
            'controller_overrides' => {},
            'vd_defaults' => {},
            'vd_overrides' => {},
          }
        end

        it { is_expected.to compile }
        
        # Check that custom types are created
        it { is_expected.to contain_megaraid_controller_setting('0:autorebuild').with_value('on') }
        it { is_expected.to contain_megaraid_controller_setting('1:autorebuild').with_value('on') }
        it { is_expected.to contain_megaraid_controller_setting('0:rebuildrate').with_value('60') }
        it { is_expected.to contain_megaraid_controller_setting('1:rebuildrate').with_value('60') }
        it { is_expected.to contain_megaraid_controller_setting('0:perfmode').with_value('0') }
        it { is_expected.to contain_megaraid_controller_setting('0:ncq').with_value('on') }
        it { is_expected.to contain_megaraid_controller_setting('0:alarm').with_value('on') }
        
        # Check patrol read
        it { is_expected.to contain_megaraid_patrolread(0).with_mode('auto') }
        it { is_expected.to contain_megaraid_patrolread(1).with_mode('auto') }
        
        # Check consistency check
        it { is_expected.to contain_megaraid_consistency_check(0).with_mode('conc') }
        it { is_expected.to contain_megaraid_consistency_check(1).with_mode('conc') }
      end

      context 'with per-controller overrides' do
        let(:facts) do
          os_facts.merge({
            'megaraid' => {
              'present?' => true,
              'storcli' => 'storcli64',
              'controllers' => {
                0 => { 'virtual_drives' => {} },
                1 => { 'virtual_drives' => {} },
              },
            },
          })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_defaults' => {
              'autorebuild' => true,
              'rebuildrate' => 60,
              'alarm' => true,
            },
            'controller_overrides' => {
              1 => {
                'alarm' => false,
                'rebuildrate' => 30,
              },
            },
            'vd_defaults' => {},
            'vd_overrides' => {},
          }
        end

        it { is_expected.to compile }
        
        # Controller 0 should use defaults
        it { is_expected.to contain_megaraid_controller_setting('0:autorebuild').with_value('on') }
        it { is_expected.to contain_megaraid_controller_setting('0:rebuildrate').with_value('60') }
        it { is_expected.to contain_megaraid_controller_setting('0:alarm').with_value('on') }
        
        # Controller 1 should use overrides
        it { is_expected.to contain_megaraid_controller_setting('1:autorebuild').with_value('on') }
        it { is_expected.to contain_megaraid_controller_setting('1:rebuildrate').with_value('30') }
        it { is_expected.to contain_megaraid_controller_setting('1:alarm').with_value('off') }
      end

      context 'pick-and-choose settings' do
        let(:facts) do
          os_facts.merge({
            'megaraid' => {
              'present?' => true,
              'storcli' => 'storcli64',
              'controllers' => {
                0 => { 'virtual_drives' => {} },
              },
            },
          })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_defaults' => {
              'autorebuild' => true,
              'alarm' => false,
            },
            'controller_overrides' => {},
            'vd_defaults' => {},
            'vd_overrides' => {},
          }
        end

        it { is_expected.to compile }
        
        # Only specified settings should be managed
        it { is_expected.to contain_megaraid_controller_setting('0:autorebuild').with_value('on') }
        it { is_expected.to contain_megaraid_controller_setting('0:alarm').with_value('off') }
        
        # Unspecified settings should not be managed
        it { is_expected.not_to contain_megaraid_controller_setting('0:rebuildrate') }
        it { is_expected.not_to contain_megaraid_controller_setting('0:perfmode') }
        it { is_expected.not_to contain_megaraid_controller_setting('0:ncq') }
        it { is_expected.not_to contain_megaraid_patrolread(0) }
        it { is_expected.not_to contain_megaraid_consistency_check(0) }
      end

      context 'with virtual drive settings' do
        let(:facts) do
          os_facts.merge({
            'megaraid' => {
              'present?' => true,
              'storcli' => 'storcli64',
              'controllers' => {
                0 => {
                  'virtual_drives' => {
                    '0' => {},
                    '1' => {},
                  },
                },
              },
            },
          })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_defaults' => {},
            'controller_overrides' => {},
            'vd_defaults' => {
              'wrcache' => 'wt',
              'rdcache' => 'ra',
            },
            'vd_overrides' => {
              '0/1' => {
                'wrcache' => 'wb',
              },
            },
          }
        end

        it { is_expected.to compile }
        
        # VD 0/0 should use defaults
        it { is_expected.to contain_megaraid_vd_setting('0/0:wrcache').with_value('wt') }
        it { is_expected.to contain_megaraid_vd_setting('0/0:rdcache').with_value('ra') }
        
        # VD 0/1 should use override for wrcache
        it { is_expected.to contain_megaraid_vd_setting('0/1:wrcache').with_value('wb') }
        it { is_expected.to contain_megaraid_vd_setting('0/1:rdcache').with_value('ra') }
      end

      context 'with sync_time_to_controllers enabled' do
        let(:facts) do
          os_facts.merge({
            'megaraid' => {
              'present?' => true,
              'storcli' => 'storcli64',
              'controllers' => {
                0 => { 'virtual_drives' => {} },
              },
            },
          })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'sync_time_to_controllers' => true,
            'controller_use_utc' => true,
            'controller_defaults' => {},
            'controller_overrides' => {},
            'vd_defaults' => {},
            'vd_overrides' => {},
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('Set time on MegaRAID controller /c0 to UTC') }
      end
    end
  end
end

