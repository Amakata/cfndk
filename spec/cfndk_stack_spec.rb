require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION']) }
  before(:each) { set_environment_variable('AWS_PROFILE', ENV['AWS_PROFILE']) }
  before(:each) { set_environment_variable('AWS_ACCESS_KEY_ID', ENV["AWS_ACCESS_KEY_ID#{TEST_ENV_NUMBER}"]) }
  before(:each) { set_environment_variable('AWS_SECRET_ACCESS_KEY', ENV["AWS_SECRET_ACCESS_KEY#{TEST_ENV_NUMBER}"]) }
  describe 'bin/cfndk' do
    before(:each) { setup_aruba }
    let(:file) { 'cfndk.yml' }
    let(:file2) { 'cfndk2.yml' }
    let(:pem) { 'test.pem' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }

    describe 'stack' do
      context 'without subcommand', help: true do
        before(:each) { run_command('cfndk stack') }
        it 'displays help and status code = 2' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(2)
          end
        end
      end

      describe 'help', help: true do
        context 'without subsubcommand' do
          before(:each) { run_command('cfndk stack help') }
          it 'displays help and status code = 2' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(2)
            end
          end
        end
      end

      describe 'validate', validate: true do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack validate') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR RuntimeError: File does not exist./)
            end
          end
        end

        context 'with cfndk2.yml' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          context 'when -c cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack validate -c=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO validate.../)
              end
            end
          end
          context 'when --config-path cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack validate --config-path=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO validate.../)
              end
            end
          end
        end
        context 'with cfndk.yml' do
          context 'when valid yaml' do
            yaml = <<-"YAML"
            stacks:
              Test:
                template_file: vpc.yaml
                parameter_input: vpc.json
                timeout_in_minutes: 2
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
            before(:each) { copy('%/vpc.json', 'vpc.json') }
            before(:each) { run_command('cfndk stack validate') }
            it 'Displays validate message'  do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(0)
                expect(last_command_started).to have_output(/INFO validate stack: Test$/)
              end
            end
          end
          context 'when empty yaml' do
            yaml = <<-"YAML"
            stacks:
              Test:
                template_file: vpc.yaml
                timeout_in_minutes: 2
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { copy('%/empty_resource.yaml', 'vpc.yaml') }
            before(:each) { run_command('cfndk stack validate') }
            it 'Displays error message and status code = 1' do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                expect(last_command_started).to have_output(/ERROR Aws::CloudFormation::Errors::ValidationError: Template format error: At least one Resources member must be defined\.$/)
              end
            end
          end
          context 'when invalid yaml' do
            yaml = <<-"YAML"
            stacks:
              Test:
                template_file: vpc.yaml
                parameter_input: vpc.json
                timeout_in_minutes: 2
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { copy('%/invalid_vpc.yaml', 'vpc.yaml') }
            before(:each) { copy('%/vpc.json', 'vpc.json') }
            before(:each) { run_command('cfndk stack validate') }
            it 'Displays error message and status code = 1' do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                expect(last_command_started).to have_output(/ERROR Aws::CloudFormation::Errors::ValidationError: \[\/Resources\] 'null' values are not allowed in templates$/)
              end
            end
          end
        end
      end
    end
  end
end
