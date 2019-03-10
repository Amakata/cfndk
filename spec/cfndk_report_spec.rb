require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) { setup_aruba }
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION']) }
  before(:each) { set_environment_variable('AWS_PROFILE', ENV['AWS_PROFILE']) }

  describe 'bin/cfndk' do
    describe 'report', report: true do
      context 'without cfndk.yml' do
        before(:each) { run_command('cfndk report') }
        it 'displays file does not exist error and status code = 1' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(1)
            expect(last_command_started).to have_output(/ERROR File does not exist./)
          end
        end
      end
      context 'with cfndk2.yml' do
        context 'when -c cfndk2.yml and empty keyparis and stacks' do
          yaml = <<-"YAML"
          keypairs:
          stacks:
          YAML
          before(:each) { write_file('cfndk2.yml', yaml) }
          before(:each) { run_command('cfndk report -c=cfndk2.yml') }
          it 'displays empty stacks and keypairs report' do
            aggregate_failures do
              expect(last_command_started).to be_successfully_executed
              expect(last_command_started).to have_output(/INFO report.../)
            end
          end
        end
      end
      context 'with cfndk.yml' do
        context 'when cfndk.yml is empty' do
          before(:each) { touch('cfndk.yml') }
          before(:each) { run_command('cfndk report') }
          it 'displays File is empty error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File is empty./)
            end
          end
        end

        context 'with empty keypairs and stacks' do
          yaml = <<-"YAML"
          keypairs:
          stacks:
          YAML
          before(:each) { write_file('cfndk.yml', yaml) }
          before(:each) { run_command('cfndk report') }
          it 'displays empty stacks and keypairs report' do
            aggregate_failures do
              expect(last_command_started).to be_successfully_executed
              expect(last_command_started).to have_output(/INFO report.../)
            end
          end
        end

        context 'with keypairs and stacks' do
          yaml = <<-"YAML"
          keypairs:
            Key1:
            Key2:
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
          context 'without UUID' do
            before(:each) { write_file('cfndk.yml', yaml) }
            before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
            before(:each) { copy('%/vpc.json', 'vpc.json') }
            before(:each) { copy('%/sg.yaml', 'sg.yaml') }
            before(:each) { copy('%/sg.json', 'sg.json') }
            before(:each) { run_command_and_stop('cfndk create') }
            context 'without option' do
              before(:each) { run_command('cfndk report') }
              it 'displays stacks report' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO stack: Test$/)
                  expect(last_command_started).to have_output(/INFO stack: Test2$/)
                end
              end
            end
            context 'when --stack-names Test2' do
              before(:each) { run_command('cfndk report --stack-names Test2') }
              it 'displays stacks report' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).not_to have_output(/INFO stack: Test$/)
                  expect(last_command_started).to have_output(/INFO stack: Test2$/)
                end
              end
            end
            context 'when --stack-names Test3' do
              before(:each) { run_command('cfndk report --stack-names Test3') }
              it 'displays stacks report' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).not_to have_output(/INFO stack: Test$/)
                  expect(last_command_started).not_to have_output(/INFO stack: Test2$/)
                  expect(last_command_started).not_to have_output(/INFO stack: Test3$/)
                end
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end
          context 'with UUID' do
            before(:each) { write_file('cfndk.yml', yaml) }
            before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
            before(:each) { copy('%/vpc.json', 'vpc.json') }
            before(:each) { copy('%/sg.yaml', 'sg.yaml') }
            before(:each) { copy('%/sg.json', 'sg.json') }
            before(:each) { run_command_and_stop('cfndk create -u 38437346-c75c-47c5-83b4-d504f85e275b') }
            context 'without option' do
              before(:each) { run_command('cfndk report -u 38437346-c75c-47c5-83b4-d504f85e275b') }
              it 'displays stacks report' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO stack: Test-38437346-c75c-47c5-83b4-d504f85e275b$/)
                  expect(last_command_started).to have_output(/INFO stack: Test2-38437346-c75c-47c5-83b4-d504f85e275b$/)
                end
              end
            end
            context 'when --stack-names Test2' do
              before(:each) { run_command('cfndk report -u 38437346-c75c-47c5-83b4-d504f85e275b --stack-names Test2') }
              it 'displays stacks report' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).not_to have_output(/INFO stack: Test-38437346-c75c-47c5-83b4-d504f85e275b$/)
                  expect(last_command_started).to have_output(/INFO stack: Test2-38437346-c75c-47c5-83b4-d504f85e275b$/)
                end
              end
            end
            context 'when --stack-names Test3' do
              before(:each) { run_command('cfndk report -u 38437346-c75c-47c5-83b4-d504f85e275b --stack-names Test3') }
              it 'displays stacks report' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).not_to have_output(/INFO stack: Test-/)
                  expect(last_command_started).not_to have_output(/INFO stack: Test2-/)
                  expect(last_command_started).not_to have_output(/INFO stack: Test3-/)
                end
              end
            end
            after(:each) { run_command('cfndk destroy -f -u 38437346-c75c-47c5-83b4-d504f85e275b') }
          end
        end
      end
    end
  end
end
