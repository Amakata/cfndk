require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  let(:aws_region) { 'ap-northeast-1' }
  let(:aws_profile) { 'magento-cfn-ci' }
  before(:each) do
    Aruba.configure { |c| c.exit_timeout = 60 * 3 }
  end

  describe 'bin/cfndk' do
    before(:each) { setup_aruba }
    let(:file) { 'cfndk.yml' }
    let(:file2) { 'cfndk2.yml' }
    let(:pem) { 'test.pem' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }


    context 'without command', help: true do
      before(:each) { run_command('cfndk') }
      it 'displays help and status code = 2' do
        aggregate_failures do
          expect(last_command_started).to have_exit_status(2)
        end
      end
    end

    describe 'version', help: true do
      before(:each) { run_command('cfndk version') }
      it 'displays version' do
        aggregate_failures do
          expect(last_command_started).to be_successfully_executed
          expect(last_command_started).to have_output(/0.0.7/)
        end
      end
    end

    describe 'generate-uuid', uuid: true do
      before(:each) { run_command('cfndk generate-uuid') }
      it 'displays UUID' do
        aggregate_failures do
          expect(last_command_started).to be_successfully_executed
          expect(last_command_started).to have_output(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        end
      end
    end

    describe 'help', help: true do
      context 'without subcommand' do
        before(:each) { run_command('cfndk help') }
        it 'displays help and status code = 2' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(2)
          end
        end
      end

      describe 'version' do
        before(:each) { run_command('cfndk help version') }
        it 'displays help of version and status code = 2' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(2)
          end
        end
      end
    end

    describe 'init', init: true do

      context 'without cfndk.yml' do
        before(:each) { run_command('cfndk init') }
        it do
          aggregate_failures do
            expect(last_command_started).to be_successfully_executed
            expect(last_command_started).to have_output(/INFO init\.\.\..+INFO create .+cfndk.yml$/m)
          end
        end
      end

      context 'with cfndk.yml' do
        before(:each) { touch(file) }
        before(:each) { run_command('cfndk init') }
        it do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(1)
            expect(last_command_started).to have_output(/ERROR File exist./)
          end
        end
      end
    end
  end
end
