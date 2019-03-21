require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION']) }
  before(:each) { set_environment_variable('AWS_PROFILE', ENV['AWS_PROFILE']) }
  before(:each) { set_environment_variable('AWS_ACCESS_KEY_ID', ENV['AWS_ACCESS_KEY_ID']) }
  before(:each) { set_environment_variable('AWS_SECRET_ACCESS_KEY', ENV['AWS_SECRET_ACCESS_KEY']) }
  describe 'bin/cfndk' do
    before(:each) { setup_aruba }
    let(:file) { 'cfndk.yml' }
    let(:file2) { 'cfndk2.yml' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }
    let(:change_set_uuid) { '38437346-c75c-47c5-83b4-d504f85e27ca' }

    describe 'changeset' do
      context 'without subcommand', help: true do
        before(:each) { run_command('cfndk changeset') }
        it 'displays help and status code = 2' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(2)
          end
        end
      end

      describe 'help', help: true do
        context 'without subsubcommand' do
          before(:each) { run_command('cfndk changeset help') }
          it 'displays help and status code = 2' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(2)
            end
          end
        end
      end
    end
  end
end
