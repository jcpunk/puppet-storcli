# frozen_string_literal: true

require 'spec_helper'

describe 'storcli::configure' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'without storcli_tool' do
        let(:facts) { os_facts.merge({ 'storcli' => { 'present' => true, 'controllers' => {} } }) }

        it { is_expected.to compile }
        it { is_expected.to have_storcli__controller_resource_count(0) }
        it { is_expected.to have_storcli__patrolread_resource_count(0) }
        it { is_expected.to have_storcli__consistencycheck_resource_count(0) }
      end

      context 'without storcli_tool, with management' do
        let(:facts) { os_facts.merge({ 'storcli' => { 'present' => true, 'controllers' => {} } }) }
        let(:params) do
          {
            'configure_settings' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to have_storcli__controller_resource_count(0) }
      end

      context 'with storcli_tool, no management' do
        let(:facts) { os_facts.merge({ 'storcli' => { 'present' => true, 'storcli_tool' => '/usr/local/sbin/storcli64', 'controllers' => {} } }) }
        let(:params) do
          {
            'configure_settings' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to have_storcli__controller_resource_count(0) }
        it { is_expected.to have_storcli__patrolread_resource_count(0) }
        it { is_expected.to have_storcli__consistencycheck_resource_count(0) }
      end

      context 'with storcli_tool, and management of config - defaults' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
          }
        end

        it { is_expected.to compile }
        # One controller + patrolread + consistencycheck per detected controller
        it { is_expected.to have_storcli__controller_resource_count(2) }
        it { is_expected.to have_storcli__patrolread_resource_count(2) }
        it { is_expected.to have_storcli__consistencycheck_resource_count(2) }
      end

      context 'with storcli_tool, and management of config - autorebuild = true' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_manage_rebuild' => true,
            'controller_autorebuild' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__controller('controller_0').with(controller: 0, autorebuild: true) }
        it { is_expected.to contain_storcli__controller('controller_1').with(controller: 1, autorebuild: true) }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(autorebuild: true) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(autorebuild: true) }
      end

      context 'with storcli_tool, and management of config - autorebuild = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_manage_rebuild' => true,
            'controller_autorebuild' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(autorebuild: false) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(autorebuild: false) }
      end

      context 'with storcli_tool, and management of config - rebuildrate=50' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_manage_rebuild' => true,
            'controller_rebuildrate' => 50,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(rebuildrate: 50) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(rebuildrate: 50) }
      end

      context 'with storcli_tool, manage_rebuild = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_manage_rebuild' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__controller('controller_0').with(autorebuild: nil, rebuildrate: nil) }
        it { is_expected.to contain_storcli_controller('controller_0_c0').without_autorebuild }
      end

      context 'with storcli_tool, sync_time_to_controllers = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'sync_time_to_controllers' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__controller('controller_0').with(sync_time: nil) }
        it { is_expected.to contain_storcli_controller('controller_0_c0').without_sync_time }
      end

      context 'with storcli_tool, sync_time = true, UTC' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'sync_time_to_controllers' => true,
            'controller_use_utc' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(sync_time: true, use_utc: true) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(sync_time: true, use_utc: true) }
      end

      context 'with storcli_tool, sync_time = true, local time' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'sync_time_to_controllers' => true,
            'controller_use_utc' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(sync_time: true, use_utc: false) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(sync_time: true, use_utc: false) }
      end

      context 'with storcli_tool, perfmode=0' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_perfmode' => 0,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(perfmode: 0) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(perfmode: 0) }
      end

      context 'with storcli_tool, ncq = true' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_ncq' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(ncq: true) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(ncq: true) }
      end

      context 'with storcli_tool, ncq = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_ncq' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(ncq: false) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(ncq: false) }
      end

      context 'with storcli_tool, manage_alarm = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_manage_alarm' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__controller('controller_0').with(alarm: nil) }
        it { is_expected.to contain_storcli_controller('controller_0_c0').without_alarm }
      end

      context 'with storcli_tool, alarm = true' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_manage_alarm' => true,
            'controller_alarm' => true,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(alarm: true) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(alarm: true) }
      end

      context 'with storcli_tool, alarm = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 2,
                             'controllers' => { 0 => {}, 1 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_manage_alarm' => true,
            'controller_alarm' => false,
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('controller_0_c0').with(alarm: false) }
        it { is_expected.to contain_storcli_controller('controller_1_c1').with(alarm: false) }
      end

      context 'with storcli_tool, patrolread mode=off' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_patrolread_mode' => 'off',
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__patrolread('controller_0').with(mode: 'off') }
        it { is_expected.to contain_storcli_patrolread('controller_0_c0').with(mode: 'off') }
      end

      context 'with storcli_tool, patrolread mode=auto' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_patrolread_mode' => 'auto',
            'controller_patrolread_delay' => 10,
            'controller_patrolread_rate' => 11,
            'controller_patrolread_includessds' => false,
            'controller_patrolread_uncfgareas' => false,
          }
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_storcli_patrolread('controller_0_c0').with(
            mode: 'auto',
            delay: 10,
            rate: 11,
            includessds: false,
            uncfgareas: false,
          )
        }
      end

      context 'with storcli_tool, consistencycheck mode=off' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_consistencycheck_mode' => 'off',
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__consistencycheck('controller_0').with(mode: 'off') }
        it { is_expected.to contain_storcli_consistencycheck('controller_0_c0').with(mode: 'off') }
      end

      context 'with storcli_tool, consistencycheck mode=conc' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 1,
                             'controllers' => { 0 => {} },
                           },
                         })
        end
        let(:params) do
          {
            'configure_settings' => true,
            'controller_consistencycheck_mode' => 'conc',
            'controller_consistencycheck_delay' => 10,
            'controller_consistencycheck_rate' => 11,
          }
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_storcli_consistencycheck('controller_0_c0').with(
            mode: 'conc',
            delay: 10,
            rate: 11,
          )
        }
      end
    end
  end
end
