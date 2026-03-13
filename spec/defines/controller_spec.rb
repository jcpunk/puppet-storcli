# frozen_string_literal: true

require 'spec_helper'

describe 'storcli::controller' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { "class { 'storcli': configure_settings => false }" }

      let(:default_facts) do
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
        let(:params) { { controller: 0, storcli_cmd: :undef } }

        it { is_expected.to compile }
        it { is_expected.to have_storcli_controller_resource_count(0) }
      end

      context 'with controller 0 and autorebuild enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, autorebuild: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(controller: 0, autorebuild: true) }
        it { is_expected.not_to contain_storcli_controller('test_c1') }
      end

      context 'with controller 0 and autorebuild disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, autorebuild: false } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(controller: 0, autorebuild: false) }
      end

      context 'with autorebuild undef (not managed)' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0 } }

        it { is_expected.to compile }
        # autorebuild should not be passed to the native type
        it { is_expected.to contain_storcli_controller('test_c0').without_autorebuild }
      end

      context 'with rebuildrate=50' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, rebuildrate: 50 } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(rebuildrate: 50) }
      end

      context 'with sync_time true and use_utc true' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, sync_time: true, use_utc: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(sync_time: true, use_utc: true) }
      end

      context 'with sync_time true and use_utc false' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, sync_time: true, use_utc: false } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(sync_time: true, use_utc: false) }
      end

      context 'with sync_time undef (not managed)' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0 } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').without_sync_time }
      end

      context 'with time_tolerance=300' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, sync_time: true, use_utc: true, time_tolerance: 300 } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(time_tolerance: 300) }
      end

      context 'with perfmode=0' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, perfmode: 0 } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(perfmode: 0) }
      end

      context 'with ncq enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, ncq: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(ncq: true) }
      end

      context 'with ncq disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, ncq: false } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(ncq: false) }
      end

      context 'with cacheflushinterval=5' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, cacheflushinterval: 5 } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(cacheflushinterval: 5) }
      end

      context 'with bootwithpinnedcache enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, bootwithpinnedcache: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(bootwithpinnedcache: true) }
      end

      context 'with bootwithpinnedcache disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, bootwithpinnedcache: false } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(bootwithpinnedcache: false) }
      end

      context 'with alarm enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, alarm: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(alarm: true) }
      end

      context 'with alarm disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, alarm: false } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(alarm: false) }
      end

      context 'with smartpollinterval=5' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, smartpollinterval: 5 } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('test_c0').with(smartpollinterval: 5) }
      end

      context "with controller => 'all'" do
        let(:title) { 'all_settings' }
        let(:facts) { default_facts }
        let(:params) { { controller: 'all', ncq: true, alarm: false } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('all_settings_c0').with(controller: 0, ncq: true, alarm: false) }
        it { is_expected.to contain_storcli_controller('all_settings_c1').with(controller: 1, ncq: true, alarm: false) }
      end

      context "with controller => 'all' and no controllers detected" do
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
        let(:params) { { controller: 'all', ncq: true } }

        it { is_expected.to compile }
        it { is_expected.to have_storcli_controller_resource_count(0) }
      end

      context 'with only some settings managed' do
        let(:title) { 'partial' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, ncq: true, alarm: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_controller('partial_c0').with(ncq: true, alarm: true) }
        it { is_expected.to contain_storcli_controller('partial_c0').without_autorebuild }
        it { is_expected.to contain_storcli_controller('partial_c0').without_sync_time }
        it { is_expected.to contain_storcli_controller('partial_c0').without_perfmode }
      end
    end
  end
end
