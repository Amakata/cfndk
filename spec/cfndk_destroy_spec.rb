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

    describe 'destroy', destroy: true do
      before(:each) { prepend_environment_variable('AWS_REGION', aws_region) }
      before(:each) { prepend_environment_variable('AWS_PROFILE', aws_profile) }

      context 'without cfndk.yml' do
        before(:each) { run_command('cfndk destroy -f') }
        it 'displays file does not exist error and status code = 1' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(1)
            expect(last_command_started).to have_output(/ERROR File does not exist./)
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
          it do
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
            before(:each) { run_command('cfndk destroy') }
            before(:each) { type('yes') }
            it do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO destroy../)
                expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                expect(last_command_started).to have_output(/INFO do not delete keypair: Test1$/)
                expect(last_command_started).to have_output(/INFO do not delete stack: Test$/)
              end
            end
          end
          context 'when keyparis and stacks exist' do
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
            before(:each) { run_command_and_stop('cfndk create') }
            before(:each) { run_command('cfndk destroy') }
            before(:each) { type('yes') }
            it do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO destroy../)
                expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                expect(last_command_started).to have_output(/INFO deleted keypair: Test1$/)
                expect(last_command_started).to have_output(/INFO deleted stack: Test$/)
              end
            end
          end
        end
      end
    end
  end
end
