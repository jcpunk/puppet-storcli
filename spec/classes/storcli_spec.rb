require 'spec_helper'

describe 'storcli' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'with card detected' do
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

        it { is_expected.to compile }

        it { is_expected.to contain_class('storcli::install') }
        it { is_expected.to contain_class('storcli::configure') }

        describe 'storcli::install' do
          let(:params) { { package_ensure: 'present', package_name: ['storcli'] } }

          it {
            is_expected.to contain_package('storcli').with(
              ensure: 'present',
            )
          }

          describe 'should allow package ensure to be overridden' do
            let(:params) { { package_ensure: 'latest', package_name: ['storcli'], package_manage: true } }

            it { is_expected.to contain_package('storcli').with_ensure('latest') }
          end

          describe 'should allow the package name to be overridden' do
            let(:params) { { package_ensure: 'present', package_name: ['hambaby'], package_manage: true } }

            it { is_expected.to contain_package('hambaby') }
          end

          describe 'should allow the package to be unmanaged' do
            let(:params) { { package_manage: false, package_name: ['storcli'] } }

            it { is_expected.not_to contain_package('storcli') }
          end

          describe 'is storcli binary already in "/usr/local/sbin"' do
            it { is_expected.not_to contain_file('/usr/local/sbin/storcli64') }
          end
        end
      end

      context 'with card detected, non-default link target' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => true,
                             'storcli_tool' => '/non/default/storcli',
                             'number_of_controllers' => 0,
                             'controllers' => {},
                           },
                         })
        end

        it { is_expected.to compile }

        it { is_expected.to contain_class('storcli::install') }

        describe 'storcli::install' do
          let(:params) { { link_storcli_to: '/tmp/sbin' } }

          describe 'is storcli binary symlinked to target location' do
            it {
              is_expected.to contain_file('/tmp/sbin') \
                .with_ensure('link') \
                .with_target('/non/default/storcli')
            }
          end
        end
      end

      context 'with card not detected' do
        let(:facts) do
          os_facts.merge({
                           'storcli' => {
                             'present' => false,
                           },
                         })
        end

        it { is_expected.to compile }

        it { is_expected.to contain_class('storcli::install') }

        describe 'storcli::install' do
          let(:params) { { package_ensure: 'present', package_name: ['storcli'] } }

          it {
            is_expected.not_to contain_package('storcli').with(
              ensure: 'present',
            )
          }
        end
      end

      context 'with hiera hash for controllers' do
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
            configure_settings: false,
            controllers: {
              'my_c0' => {
                'controller' => 0,
                'ncq' => true,
              },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__controller('my_c0').with(controller: 0, ncq: true) }
      end

      context 'with hiera hash for patrolreads' do
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
            configure_settings: false,
            patrolreads: {
              'my_pr' => {
                'controller' => 'all',
                'mode' => 'auto',
                'rate' => 30,
              },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__patrolread('my_pr').with(controller: 'all', mode: 'auto', rate: 30) }
      end

      context 'with hiera hash for consistencychecks' do
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
            configure_settings: false,
            consistencychecks: {
              'my_cc' => {
                'controller' => 'all',
                'mode' => 'conc',
                'delay' => 672,
              },
            },
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_storcli__consistencycheck('my_cc').with(controller: 'all', mode: 'conc', delay: 672) }
      end
    end
  end
end
