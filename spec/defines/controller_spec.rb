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
                           'storcli_tool' => '/usr/local/sbin/storcli64',
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
        it { is_expected.not_to contain_exec('test: Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable autorebuild on MegaRAID controller /c0') }
      end

      context 'with controller 0 and autorebuild enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, autorebuild: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Enable autorebuild on MegaRAID controller /c1') }
      end

      context 'with controller 0 and autorebuild disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, autorebuild: false } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable autorebuild on MegaRAID controller /c0') }
      end

      context 'with autorebuild undef (not managed)' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0 } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable autorebuild on MegaRAID controller /c0') }
      end

      context 'with rebuildrate=50' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, rebuildrate: 50 } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Set rebuildrate=50% on MegaRAID controller /c0') }
      end

      context 'with sync_time true and use_utc true' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, sync_time: true, use_utc: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.not_to contain_exec('test: Set time on MegaRAID controller /c0 to local time') }
      end

      context 'with sync_time true and use_utc false' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, sync_time: true, use_utc: false } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.to contain_exec('test: Set time on MegaRAID controller /c0 to local time') }
      end

      context 'with sync_time undef (not managed)' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0 } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.not_to contain_exec('test: Set time on MegaRAID controller /c0 to local time') }
      end

      context 'with time_tolerance=300' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, sync_time: true, use_utc: true, time_tolerance: 300 } }

        it { is_expected.to compile }
        it {
          is_expected.to contain_exec('test: Set time on MegaRAID controller /c0 to UTC')
            .with_unless(%r{-le 300})
        }
      end

      context 'with perfmode=0' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, perfmode: 0 } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Set perfmode=0 on MegaRAID controller /c0') }
      end

      context 'with ncq enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, ncq: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable NCQ on MegaRAID controller /c0') }
      end

      context 'with ncq disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, ncq: false } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable NCQ on MegaRAID controller /c0') }
      end

      context 'with cacheflushinterval=5' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, cacheflushinterval: 5 } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Set cacheflushinterval=5 on MegaRAID controller /c0') }
      end

      context 'with bootwithpinnedcache enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, bootwithpinnedcache: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Enable bootwithpinnedcache on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable bootwithpinnedcache on MegaRAID controller /c0') }
      end

      context 'with bootwithpinnedcache disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, bootwithpinnedcache: false } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Enable bootwithpinnedcache on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable bootwithpinnedcache on MegaRAID controller /c0') }
      end

      context 'with alarm enabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, alarm: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Enable alarm sound on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('test: Disable alarm sound on MegaRAID controller /c0') }
      end

      context 'with alarm disabled' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, alarm: false } }

        it { is_expected.to compile }
        it { is_expected.not_to contain_exec('test: Enable alarm sound on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('test: Disable alarm sound on MegaRAID controller /c0') }
      end

      context 'with smartpollinterval=5' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, smartpollinterval: 5 } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('test: Set smartpollinterval=5 on MegaRAID controller /c0') }
      end

      context "with controller => 'all'" do
        let(:title) { 'all_settings' }
        let(:facts) { default_facts }
        let(:params) { { controller: 'all', ncq: true, alarm: false } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('all_settings: Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('all_settings: Enable NCQ on MegaRAID controller /c1') }
        it { is_expected.to contain_exec('all_settings: Disable alarm sound on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('all_settings: Disable alarm sound on MegaRAID controller /c1') }
      end

      context "with controller => 'all' and no controllers detected" do
        let(:title) { 'test' }
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/usr/local/sbin/storcli64',
                             'number_of_controllers' => 0,
                             'controllers' => {},
                           },
                         })
        end
        let(:params) { { controller: 'all', ncq: true } }

        it { is_expected.to compile }
        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with only some settings managed' do
        let(:title) { 'partial' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, ncq: true, alarm: true } }

        it { is_expected.to compile }
        it { is_expected.to contain_exec('partial: Enable NCQ on MegaRAID controller /c0') }
        it { is_expected.to contain_exec('partial: Enable alarm sound on MegaRAID controller /c0') }
        # Everything else should be unmanaged
        it { is_expected.not_to contain_exec('partial: Enable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('partial: Disable autorebuild on MegaRAID controller /c0') }
        it { is_expected.not_to contain_exec('partial: Set time on MegaRAID controller /c0 to UTC') }
        it { is_expected.not_to contain_exec('partial: Set time on MegaRAID controller /c0 to local time') }
      end
    end
  end
end
