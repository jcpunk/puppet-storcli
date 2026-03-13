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
        let(:facts) { os_facts.merge({ 'storcli' => { 'present' => true, 'storcli_tool' => 'storcli64', 'controllers' => {} } }) }
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
                             'storcli_tool' => 'storcli64',
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
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Enable autorebuild on MegaRAID controller /c1') }
        it { is_expected.not_to contain_exec('controller_0: Disable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('controller_1: Disable autorebuild on MegaRAID controller /c1') }
      end

      context 'with storcli_tool, and management of config - autorebuild = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.not_to contain_exec('controller_0: Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('controller_1: Enable autorebuild on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('controller_0: Disable autorebuild on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Disable autorebuild on MegaRAID controller /c1') }
      end

      context 'with storcli_tool, and management of config - rebuildrate=50' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Set rebuildrate=50% on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Set rebuildrate=50% on MegaRAID controller /c1') }
      end

      context 'with storcli_tool, manage_rebuild = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.not_to contain_exec('controller_0: Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('controller_0: Disable autorebuild on MegaRAID controller /c0') }
      end

      context 'with storcli_tool, sync_time_to_controllers = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.not_to contain_exec('controller_0: Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.not_to contain_exec('controller_0: Set time on MegaRAID controller /c0 to local time') }
      end

      context 'with storcli_tool, sync_time = true, UTC' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.to contain_exec('controller_1: Set time on MegaRAID controller /c1 to UTC') }
        it { is_expected.not_to contain_exec('controller_0: Set time on MegaRAID controller /c0 to local time') }
      end

      context 'with storcli_tool, sync_time = true, local time' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.not_to contain_exec('controller_0: Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.to contain_exec('controller_0: Set time on MegaRAID controller /c0 to local time') }
        it { is_expected.to contain_exec('controller_1: Set time on MegaRAID controller /c1 to local time') }
      end

      context 'with storcli_tool, perfmode=0' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Set perfmode=0 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Set perfmode=0 on MegaRAID controller /c1') }
      end

      context 'with storcli_tool, ncq = true' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Enable NCQ on MegaRAID controller /c1') }
        it { is_expected.not_to contain_exec('controller_0: Disable NCQ on MegaRAID controller /c0') }
      end

      context 'with storcli_tool, ncq = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.not_to contain_exec('controller_0: Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_0: Disable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Disable NCQ on MegaRAID controller /c1') }
      end

      context 'with storcli_tool, manage_alarm = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.not_to contain_exec('controller_0: Enable alarm sound on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('controller_0: Disable alarm sound on MegaRAID controller /c0') }
      end

      context 'with storcli_tool, alarm = true' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Enable alarm sound on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Enable alarm sound on MegaRAID controller /c1') }
      end

      context 'with storcli_tool, alarm = false' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Disable alarm sound on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_1: Disable alarm sound on MegaRAID controller /c1') }
      end

      context 'with storcli_tool, patrolread mode=off' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Disable patrolread on MegaRAID controller /c0') }
      end

      context 'with storcli_tool, patrolread mode=auto' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Enable patrolread mode=auto on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_0: Set patrolread delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_0: Set patrolread rate=11% on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_0: Disable patrolread on SSDs on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_0: Disable patrolread on unconfigured areas on MegaRAID controller /c0') }
      end

      context 'with storcli_tool, consistencycheck mode=off' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Disable consistency check on MegaRAID controller /c0') }
      end

      context 'with storcli_tool, consistencycheck mode=conc' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => 'storcli64',
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
        it { is_expected.to contain_exec('controller_0: Enable consistency check mode=conc on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_0: Set consistency check delay=10 on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('controller_0: Set consistency check rate=11% on MegaRAID controller /c0') }
      end
    end
  end
end
