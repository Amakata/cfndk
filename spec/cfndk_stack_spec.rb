require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) do
    Aruba.configure { |c| c.exit_timeout = 60 * 3 }
  end
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION']) }
  before(:each) { set_environment_variable('AWS_PROFILE', ENV['AWS_PROFILE']) }
  describe 'bin/cfndk' do
    before(:each) { setup_aruba }
    let(:file) { 'cfndk.yml' }
    let(:file2) { 'cfndk2.yml' }
    let(:pem) { 'test.pem' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }

    describe 'stack' do
      describe 'create' do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack create') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File does not exist./)
            end
          end
        end

        context 'with cfndk2.yml' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          context 'when -c cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack create -c=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO create.../)
              end
            end
          end
  
          context 'when --config-path cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack create --config-path=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO create.../)
              end
            end
          end
        end
      end

      describe 'destroy', destroy: true do
        context 'when -f without cfndk.yml' do
          before(:each) { run_command('cfndk stack destroy -f') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File does not exist./)
            end
          end
        end

        context 'with cfndk2.yml' do
          yaml = <<-"YAML"
          stacks:
          YAML
          before(:each) { write_file(file2, yaml) }
          context 'when -c cfndk2.yml -f and empty stacks' do
            before(:each) { run_command("cfndk stack destroy -c=#{file2} -f") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO destroy.../)
              end
            end
          end
  
          context 'when --config-path cfndk2.yml -f and empty stacks' do
            before(:each) { run_command("cfndk stack destroy --config-path=#{file2} -f") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO destroy.../)
              end
            end
          end
        end
      end

      describe 'update' do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack update') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File does not exist./)
            end
          end
        end

        context 'with cfndk2.yml' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          context 'when -c cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack update -c=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO update.../)
              end
            end
          end
  
          context 'when --config-path cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack update --config-path=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO update.../)
              end
            end
          end
        end
      end

      describe 'validate' do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack validate') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File does not exist./)
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
      end

      describe 'report' do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack report') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File does not exist./)
            end
          end
        end

        context 'with cfndk2.yml' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          context 'when -c cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack report -c=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO report.../)
              end
            end
          end
  
          context 'when --config-path cfndk2.yml and empty stacks' do
            before(:each) { run_command("cfndk stack report --config-path=#{file2}") }
            it 'displays empty stack log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO report.../)
              end
            end
          end
        end
      end
    end
  end
end
