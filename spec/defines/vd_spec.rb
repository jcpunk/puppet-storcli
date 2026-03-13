# frozen_string_literal: true

require 'spec_helper'

describe 'storcli::vd' do
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
        let(:params) { { controller: 0, virtual_disk: 0, storcli_cmd: :undef } }

        it { is_expected.to compile }
        it { is_expected.to have_storcli_vd_resource_count(0) }
      end

      context 'with write_policy=wb on all VDs' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, virtual_disk: 'all', write_policy: 'wb' } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_vd('test').with(controller: 0, virtual_disk: 'all', write_policy: 'wb') }
      end

      context 'with all cache policies set' do
        let(:title) { 'test' }
        let(:facts) { default_facts }
        let(:params) do
          {
            controller: 0,
            virtual_disk: 1,
            write_policy: 'awb',
            read_policy: 'ra',
            io_policy: 'direct',
            disk_cache: 'default',
          }
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_storcli_vd('test').with(
            write_policy: 'awb',
            read_policy: 'ra',
            io_policy: 'direct',
            disk_cache: 'default',
          )
        }
      end

      context 'with controller=all and virtual_disk=all' do
        let(:title) { 'fleet' }
        let(:facts) { default_facts }
        let(:params) { { controller: 'all', virtual_disk: 'all', write_policy: 'wt' } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_vd('fleet').with(controller: 'all', virtual_disk: 'all', write_policy: 'wt') }
      end

      context 'with only write_policy set (others undef)' do
        let(:title) { 'minimal' }
        let(:facts) { default_facts }
        let(:params) { { controller: 0, virtual_disk: 0, write_policy: 'wb' } }

        it { is_expected.to compile }
        it { is_expected.to contain_storcli_vd('minimal').with(write_policy: 'wb') }
        it { is_expected.to contain_storcli_vd('minimal').without_read_policy }
        it { is_expected.to contain_storcli_vd('minimal').without_io_policy }
        it { is_expected.to contain_storcli_vd('minimal').without_disk_cache }
      end
    end
  end
end
