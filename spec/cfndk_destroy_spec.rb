require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION']) }
  before(:each) { set_environment_variable('AWS_PROFILE', "#{ENV['AWS_PROFILE']}#{ENV['TEST_ENV_NUMBER']}") }
  before(:each) { set_environment_variable('AWS_ACCESS_KEY_ID', "#{ENV['AWS_ACCESS_KEY_ID']}#{ENV['TEST_ENV_NUMBER']}") }
  before(:each) { set_environment_variable('AWS_SECRET_ACCESS_KEY', "#{ENV['AWS_SECRET_ACCESS_KEY']}#{ENV['TEST_ENV_NUMBER']}") }
  describe 'bin/cfndk' do
    before(:each) { setup_aruba }
    let(:file) { 'cfndk.yml' }
    let(:file2) { 'cfndk2.yml' }
    let(:pem) { 'test.pem' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }

    describe 'destroy', destroy: true do
      context 'without cfndk.yml' do
        before(:each) { run_command('cfndk destroy -f') }
        it 'displays file does not exist error and status code = 1' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(1)
            expect(last_command_started).to have_output(/ERROR RuntimeError: File does not exist./)
          end
        end
      end
      context 'with cfndk2.yml' do
        context 'when -c cfndk2.yml and empty stacks' do
          yaml = <<-"YAML"
          stacks:
          YAML
          before(:each) { write_file(file2, yaml) }
          before(:each) { run_command("cfndk destroy -f -c=#{file2}") }
          it do
            aggregate_failures do
              expect(last_command_started).to be_successfully_executed
              expect(last_command_started).to have_output(/INFO destroy.../)
            end
          end
        end
      end
      context 'with cfndk.yml' do
        context 'when cfndk.yml is empty' do
          before(:each) { touch(file) }
          before(:each) { run_command('cfndk destroy -f') }
          it 'displays File is empty error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File is empty./)
            end
          end
        end
        context 'when enter no' do
          yaml = <<-"YAML"
          keypairs:
            Test1:
          stacks:
            Test:
              template_file: vpc.yaml
              parameter_input: vpc.json
              parameters:
                VpcName: sample<%= append_uuid%>
              timeout_in_minutes: 2
          YAML
          before(:each) { write_file(file, yaml) }
          before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
          before(:each) { copy('%/vpc.json', 'vpc.json') }
          before(:each) { run_command('cfndk destroy') }
          before(:each) { type('no') }
          it 'displays confirm message and cancel message and status code = 2' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(2)
              expect(last_command_started).to have_output(/INFO destroy../)
              expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
              expect(last_command_started).to have_output(/INFO destroy command was canceled/)
              expect(last_command_started).not_to have_output(/INFO deleting stack:/)
              expect(last_command_started).not_to have_output(/INFO deleted stack:/)
              expect(last_command_started).not_to have_output(/INFO do not delete keypair: Test1$/)
              expect(last_command_started).not_to have_output(/INFO do not delete stack: Test$/)
            end
          end
        end
        context 'when enter yes' do
          context 'when keyparis and stacks do not exist' do
            yaml = <<-"YAML"
            keypairs:
              Test1:
            stacks:
              Test:
                template_file: vpc.yaml
                parameter_input: vpc.json
                parameters:
                  VpcName: sample<%= append_uuid%>
                timeout_in_minutes: 2
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
            before(:each) { copy('%/vpc.json', 'vpc.json') }
            before(:each) { run_command('cfndk destroy -f') }
            before(:each) { stop_all_commands }
            before(:each) { run_command('cfndk destroy') }
            before(:each) { type('yes') }
            before(:each) { stop_all_commands }
            it 'displays confirm message and do not delete message' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO destroy../)
                expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                expect(last_command_started).to have_output(/INFO do not delete keypair: Test1$/)
                expect(last_command_started).to have_output(/INFO do not delete stack: Test$/)
              end
            end
          end
          context 'when keyparis and stacks exist', aaa: true do
            yaml = <<-"YAML"
            keypairs:
              Test1:
            stacks:
              Test:
                template_file: vpc.yaml
                parameter_input: vpc.json
                parameters:
                  VpcName: sample<%= append_uuid%>
                timeout_in_minutes: 2
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
            before(:each) { copy('%/vpc.json', 'vpc.json') }
            before(:each) { run_command('cfndk create') }
            before(:each) { stop_all_commands }
            before(:each) { run_command('cfndk destroy') }
            before(:each) { type('yes') }
            before(:each) { stop_all_commands }
            it 'displays confirm message and delete message and stack was deleted' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO destroy../)
                expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                expect(last_command_started).to have_output(/INFO deleted keypair: Test1$/)
                expect(last_command_started).to have_output(/INFO deleted stack: Test$/)
                expect { cloudformation_stack('Test').exist }.to raise_error(Aws::CloudFormation::Errors::ValidationError)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end
        end
      end
    end
  end
end
