require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION']) }
  before(:each) { set_environment_variable('AWS_PROFILE', ENV['AWS_PROFILE']) }
  before(:each) { set_environment_variable('AWS_ACCESS_KEY_ID', ENV["AWS_ACCESS_KEY_ID#{ENV['TEST_ENV_NUMBER']}"]) }
  before(:each) { set_environment_variable('AWS_SECRET_ACCESS_KEY', ENV["AWS_SECRET_ACCESS_KEY#{ENV['TEST_ENV_NUMBER']}"]) }
  describe 'bin/cfndk' do
    before(:each) { setup_aruba }
    let(:file) { 'cfndk.yml' }
    let(:file2) { 'cfndk2.yml' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }
    let(:change_set_uuid) { '38437346-c75c-47c5-83b4-d504f85e27ca' }

    describe 'changeset' do
      describe 'report', report: true do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk changeset report') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR RuntimeError: File does not exist./)
            end
          end
        end

        context 'with cfndk.yml' do
          context 'when cfndk.yml is empty' do
            before(:each) { touch(file) }
            before(:each) { run_command('cfndk changeset report') }
            it 'displays File is empty error and status code = 1' do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/ERROR File is empty./)
              end
            end
          end

          context 'with stacks:' do
            context 'without stack' do
              before(:each) { write_file(file, 'stacks:') }
              before(:each) { run_command('cfndk changeset report') }
              it 'displays report log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO report.../)
                end
              end
            end

            context 'with a stack' do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 3
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
              before(:each) { copy('%/vpc.json', 'vpc.json') }
              before(:each) { run_command_and_stop('cfndk changeset create') }
              before(:each) { run_command('cfndk changeset report') }
              it 'displays report log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO change set: Test$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with two stacks' do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
                Test2:
                  template_file: sg.yaml
                  parameter_input: sg.json
                  depends:
                    - Test
              YAML

              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
              before(:each) { copy('%/vpc.json', 'vpc.json') }
              before(:each) { copy('%/sg.yaml', 'sg.yaml') }
              before(:each) { copy('%/sg.json', 'sg.json') }
              before(:each) { run_command_and_stop('cfndk changeset create') }
              before(:each) { run_command('cfndk changeset report') }
              it 'displays report logs' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO change set: Test$/)
                  expect(last_command_started).to have_output(/INFO change set: Test2$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
          end
        end
      end
    end
  end
end
