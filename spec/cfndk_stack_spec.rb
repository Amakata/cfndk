require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION']) }
  before(:each) { set_environment_variable('AWS_PROFILE', ENV['AWS_PROFILE']) }
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

      describe 'create', create: true do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack create') }
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

        context 'with cfndk.yml' do
          context 'when cfndk.yml is empty' do
            before(:each) { touch(file) }
            before(:each) { run_command('cfndk stack create') }
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
              before(:each) { run_command('cfndk stack create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO create.../)
                end
              end
            end

            context 'with a stack' do
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
              before(:each) { run_command('cfndk stack create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
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
              before(:each) { run_command('cfndk stack create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(/INFO validate stack: Test2$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test2$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test2$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'when invalid dependency', dependency: true do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
                  depends:
                    - Test2
                Test2:
                  template_file: sg.yaml
                  parameter_input: sg.json
              YAML

              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
              before(:each) { copy('%/vpc.json', 'vpc.json') }
              before(:each) { copy('%/sg.yaml', 'sg.yaml') }
              before(:each) { copy('%/sg.json', 'sg.json') }
              before(:each) { run_command('cfndk stack create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to have_exit_status(1)
                  expect(last_command_started).to have_output(/ERROR stopped waiting, encountered a failure state$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'when cyclic dependency', dependency: true do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
                  depends:
                    - Test2
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
              before(:each) { run_command('cfndk stack create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to have_exit_status(1)
                  expect(last_command_started).to have_output(/ERROR There are cyclic dependency or stack doesn't exist. unprocessed_stack: Test,Test2$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'when requires capabilities without capabilities', capabilities: true do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: iam.yaml
                  parameter_input: iam.json
                  timeout_in_minutes: 2
              YAML

              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/iam.yaml', 'iam.yaml') }
              before(:each) { copy('%/iam.json', 'iam.json') }
              before(:each) { run_command('cfndk stack create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to have_exit_status(1)
                  expect(last_command_started).to have_output(/ERROR Requires capabilities : \[CAPABILITY_NAMED_IAM\]/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'when success with capabilities', capabilities: true do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: iam.yaml
                  parameter_input: iam.json
                  capabilities:
                    - CAPABILITY_NAMED_IAM
                  timeout_in_minutes: 3
              YAML

              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/iam.yaml', 'iam.yaml') }
              before(:each) { copy('%/iam.json', 'iam.json') }
              before(:each) { run_command('cfndk stack create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with UUID', uuid: true do
              context 'when -u 38437346-c75c-47c5-83b4-d504f85e275b' do
                yaml = <<-"YAML"
                stacks:
                  Test:
                    template_file: vpc.yaml
                    parameter_input: vpc.json
                    parameters:
                      VpcName: sample<%= append_uuid%>
                    timeout_in_minutes: 2
                  Test2:
                    template_file: sg.yaml
                    parameter_input: sg.json
                    parameters:
                      VpcName: sample<%= append_uuid%>
                    depends:
                      - Test
                YAML
                before(:each) { write_file(file, yaml) }
                before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                before(:each) { copy('%/vpc.json', 'vpc.json') }
                before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                before(:each) { copy('%/sg.json', 'sg.json') }
                before(:each) { run_command("cfndk stack create -u=#{uuid}") }
                it do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO creating stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO created stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO creating stack: Test2-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO created stack: Test2-#{uuid}$/)
                  end
                end
                after(:each) { run_command("cfndk destroy -f -u=#{uuid}") }
              end
              context 'when env CFNDK_UUID=38437346-c75c-47c5-83b4-d504f85e275b' do
                before(:each) { set_environment_variable('CFNDK_UUID', uuid) }
                context 'with two stacks' do
                  yaml = <<-"YAML"
                  stacks:
                    Test:
                      template_file: vpc.yaml
                      parameter_input: vpc.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      timeout_in_minutes: 2
                    Test2:
                      template_file: sg.yaml
                      parameter_input: sg.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      depends:
                        - Test
                  YAML
                  before(:each) { write_file(file, yaml) }
                  before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/vpc.json', 'vpc.json') }
                  before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                  before(:each) { copy('%/sg.json', 'sg.json') }
                  before(:each) { run_command('cfndk stack create') }
                  it do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO created stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO created stack: Test2-#{uuid}$/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
                context 'when --stack-names=Test' do
                  yaml = <<-"YAML"
                  stacks:
                    Test:
                      template_file: vpc.yaml
                      parameter_input: vpc.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      timeout_in_minutes: 2
                    Test2:
                      template_file: sg.yaml
                      parameter_input: sg.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      depends:
                        - Test
                  YAML
                  before(:each) { write_file(file, yaml) }
                  before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/vpc.json', 'vpc.json') }
                  before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                  before(:each) { copy('%/sg.json', 'sg.json') }
                  before(:each) { run_command('cfndk stack create --stack-names=Test') }
                  it do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO create.../)
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO created stack: Test-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO creating stack: Test2-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO created stack: Test2-#{uuid}$/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
                context 'when --stack-names=Test Test2' do
                  yaml = <<-"YAML"
                  stacks:
                    Test:
                      template_file: vpc.yaml
                      parameter_input: vpc.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      timeout_in_minutes: 2
                    Test2:
                      template_file: sg.yaml
                      parameter_input: sg.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      depends:
                        - Test
                    Test3:
                      template_file: iam.yaml
                      parameter_input: iam.json
                      parameters:
                        WebRoleName: WebhRole<%= append_uuid%>
                      capabilities:
                        - CAPABILITY_NAMED_IAM
                      timeout_in_minutes: 3
                  YAML
                  before(:each) { write_file(file, yaml) }
                  before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/vpc.json', 'vpc.json') }
                  before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                  before(:each) { copy('%/sg.json', 'sg.json') }
                  before(:each) { copy('%/iam.yaml', 'iam.yaml') }
                  before(:each) { copy('%/iam.json', 'iam.json') }
                  before(:each) { run_command('cfndk stack create --stack-names=Test Test2') }
                  it do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO create.../)
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO created stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO created stack: Test2-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO validate stack: Test3-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO creating stack: Test3-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO created stack: Test3-#{uuid}$/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
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
              expect(last_command_started).to have_output(/ERROR RuntimeError: File does not exist./)
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

        context 'with cfndk.yml' do
          context 'when cfndk.yml is empty' do
            before(:each) { touch(file) }
            before(:each) { run_command('cfndk stack destroy -f') }
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
            before(:each) { run_command('cfndk stack destroy') }
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
              before(:each) { run_command('cfndk stack destroy') }
              before(:each) { type('yes') }
              before(:each) { stop_all_commands }
              it 'displays confirm message and do not delete message' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO destroy../)
                  expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                  expect(last_command_started).not_to have_output(/INFO do not delete keypair: Test1$/)
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
              before(:each) { run_command('cfndk create') }
              before(:each) { stop_all_commands }
              before(:each) { run_command('cfndk stack destroy') }
              before(:each) { type('yes') }
              before(:each) { stop_all_commands }
              it 'displays confirm message and delete message' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO destroy../)
                  expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                  expect(last_command_started).not_to have_output(/INFO deleted keypair: Test1$/)
                  expect(last_command_started).to have_output(/INFO deleted stack: Test$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
          end
        end
      end

      describe 'update', update: true do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack update') }
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

        context 'with cfndk.yml' do
          context 'when cfndk.yml is empty' do
            before(:each) { touch(file) }
            before(:each) { run_command('cfndk stack update') }
            it 'displays File is empty error and status code = 1' do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/ERROR File is empty./)
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
            before(:each) { run_command('cfndk stack update') }
            it 'Displays error message and status code = 1' do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                expect(last_command_started).to have_output(/ERROR Template format error: At least one Resources member must be defined\.$/)
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
            before(:each) { run_command('cfndk stack update') }
            it 'Displays error message and status code = 1' do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                expect(last_command_started).to have_output(/ERROR \[\/Resources\] 'null' values are not allowed in templates$/)
              end
            end
          end

          context 'with stacks:' do
            context 'without stack' do
              before(:each) { write_file(file, 'stacks:') }
              before(:each) { run_command('cfndk stack update') }
              it do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO update.../)
                end
              end
            end

            context 'with a stack', with_stack: true do
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
              context 'when stack already exist' do
                context 'when same yaml' do
                  before(:each) { run_command_and_stop('cfndk stack create') }
                  before(:each) { run_command('cfndk stack update') }
                  it 'displays No update warn' do
                    aggregate_failures do
                      expect(last_command_started).to have_exit_status(0)
                      expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                      expect(last_command_started).to have_output(/INFO updating stack: Test$/)
                      expect(last_command_started).to have_output(/WARN No updates are to be performed\.: Test$/)
                    end
                  end
                end
                context 'when different yaml' do
                  before(:each) { run_command_and_stop('cfndk stack create') }
                  before(:each) { copy('%/vpc_different.yaml', 'vpc.yaml') }
                  before(:each) { run_command('cfndk stack update') }
                  it 'displays update log' do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                      expect(last_command_started).to have_output(/INFO updating stack: Test$/)
                      expect(last_command_started).to have_output(/INFO updated stack: Test$/)
                    end
                  end
                end
              end
              context 'when stack does not exist' do
                before(:each) { run_command('cfndk stack update') }
                it 'displays no stack error and statu code = 1' do
                  aggregate_failures do
                    expect(last_command_started).to have_exit_status(1)
                    expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                    expect(last_command_started).to have_output(/INFO updating stack: Test$/)
                    expect(last_command_started).to have_output(/ERROR Stack \[Test\] does not exist$/)
                  end
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
                  timeout_in_minutes: 4
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
              before(:each) { run_command_and_stop('cfndk stack create') }
              before(:each) { copy('%/sg_different.yaml', 'sg.yaml') }
              before(:each) { run_command('cfndk stack update') }
              it 'displays updated logs' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO updating stack: Test$/)
                  expect(last_command_started).to have_output(/WARN No updates are to be performed.: Test$/)
                  expect(last_command_started).to have_output(/INFO validate stack: Test2$/)
                  expect(last_command_started).to have_output(/INFO updating stack: Test2$/)
                  expect(last_command_started).to have_output(/INFO updated stack: Test2$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'when cyclic dependency', dependency: true do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
                  depends:
                    - Test2
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
              before(:each) { run_command('cfndk stack update') }
              it 'displays cyclic error log and exit status = 1' do
                aggregate_failures do
                  expect(last_command_started).to have_exit_status(1)
                  expect(last_command_started).to have_output(/ERROR There are cyclic dependency or stack doesn't exist. unprocessed_stack: Test,Test2$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'when requires capabilities without capabilities', capabilities: true do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: iam.yaml
                  parameter_input: iam.json
                  capabilities:
                    - CAPABILITY_NAMED_IAM
                  timeout_in_minutes: 3
              YAML
              yaml2 = <<-"YAML"
              stacks:
                Test:
                  template_file: iam.yaml
                  parameter_input: iam.json
                  timeout_in_minutes: 2
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/iam.yaml', 'iam.yaml') }
              before(:each) { copy('%/iam.json', 'iam.json') }
              before(:each) { run_command_and_stop('cfndk stack create') }
              before(:each) { write_file(file, yaml2) }
              before(:each) { run_command('cfndk stack update') }
              it 'displays Requires capabilities log and exit status = 1' do
                aggregate_failures do
                  expect(last_command_started).to have_exit_status(1)
                  expect(last_command_started).to have_output(/ERROR Requires capabilities : \[CAPABILITY_NAMED_IAM\]/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'when success with capabilities', capabilities: true do
              yaml = <<-"YAML"
              stacks:
                Test:
                  template_file: iam.yaml
                  parameter_input: iam.json
                  capabilities:
                    - CAPABILITY_NAMED_IAM
                  timeout_in_minutes: 3
              YAML

              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/iam.yaml', 'iam.yaml') }
              before(:each) { copy('%/iam.json', 'iam.json') }
              before(:each) { run_command_and_stop('cfndk stack create') }
              before(:each) { copy('%/iam_different.json', 'iam.json') }
              before(:each) { run_command('cfndk stack update') }
              it 'displays updated log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO updated stack: Test$/)
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with UUID', uuid: true do
              context 'when -u 38437346-c75c-47c5-83b4-d504f85e275b' do
                yaml = <<-"YAML"
                stacks:
                  Test:
                    template_file: vpc.yaml
                    parameter_input: vpc.json
                    parameters:
                      VpcName: sample<%= append_uuid%>
                    timeout_in_minutes: 2
                  Test2:
                    template_file: sg.yaml
                    parameter_input: sg.json
                    parameters:
                      VpcName: sample<%= append_uuid%>
                    depends:
                      - Test
                YAML
                before(:each) { write_file(file, yaml) }
                before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                before(:each) { copy('%/vpc.json', 'vpc.json') }
                before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                before(:each) { copy('%/sg.json', 'sg.json') }
                before(:each) { run_command_and_stop("cfndk stack create -u=#{uuid}") }
                before(:each) { copy('%/vpc_different.yaml', 'vpc.yaml') }
                before(:each) { copy('%/sg_different.yaml', 'sg.yaml') }
                before(:each) { run_command("cfndk stack update -u=#{uuid}") }
                it 'displays updated logs' do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO updating stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO updated stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO updating stack: Test2-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO updated stack: Test2-#{uuid}$/)
                  end
                end
                after(:each) { run_command("cfndk destroy -f -u=#{uuid}") }
              end
              context 'when env CFNDK_UUID=38437346-c75c-47c5-83b4-d504f85e275b' do
                before(:each) { set_environment_variable('CFNDK_UUID', uuid) }
                context 'with two stacks' do
                  yaml = <<-"YAML"
                  stacks:
                    Test:
                      template_file: vpc.yaml
                      parameter_input: vpc.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      timeout_in_minutes: 2
                    Test2:
                      template_file: sg.yaml
                      parameter_input: sg.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      depends:
                        - Test
                  YAML
                  before(:each) { write_file(file, yaml) }
                  before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/vpc.json', 'vpc.json') }
                  before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                  before(:each) { copy('%/sg.json', 'sg.json') }
                  before(:each) { run_command_and_stop('cfndk stack create') }
                  before(:each) { copy('%/vpc_different.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/sg_different.yaml', 'sg.yaml') }
                  before(:each) { run_command('cfndk stack update') }
                  it 'displays updated logs' do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updating stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updated stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updating stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updated stack: Test2-#{uuid}$/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
                context 'when --stack-names=Test' do
                  yaml = <<-"YAML"
                  stacks:
                    Test:
                      template_file: vpc.yaml
                      parameter_input: vpc.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      timeout_in_minutes: 2
                    Test2:
                      template_file: sg.yaml
                      parameter_input: sg.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      depends:
                        - Test
                  YAML
                  before(:each) { write_file(file, yaml) }
                  before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/vpc.json', 'vpc.json') }
                  before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                  before(:each) { copy('%/sg.json', 'sg.json') }
                  before(:each) { run_command_and_stop('cfndk stack create') }
                  before(:each) { copy('%/vpc_different.yaml', 'vpc.yaml') }
                  before(:each) { run_command('cfndk stack update --stack-names=Test') }
                  it 'displays updated log of Test stack' do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO update.../)
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updating stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updated stack: Test-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO updating stack: Test2-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO updated stack: Test2-#{uuid}$/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
                context 'when --stack-names=Test Test2' do
                  yaml = <<-"YAML"
                  stacks:
                    Test:
                      template_file: vpc.yaml
                      parameter_input: vpc.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      timeout_in_minutes: 2
                    Test2:
                      template_file: sg.yaml
                      parameter_input: sg.json
                      parameters:
                        VpcName: sample<%= append_uuid%>
                      depends:
                        - Test
                    Test3:
                      template_file: iam.yaml
                      parameter_input: iam.json
                      parameters:
                        WebRoleName: WebhRole<%= append_uuid%>
                      capabilities:
                        - CAPABILITY_NAMED_IAM
                      timeout_in_minutes: 3
                  YAML
                  before(:each) { write_file(file, yaml) }
                  before(:each) { copy('%/vpc.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/vpc.json', 'vpc.json') }
                  before(:each) { copy('%/sg.yaml', 'sg.yaml') }
                  before(:each) { copy('%/sg.json', 'sg.json') }
                  before(:each) { copy('%/iam.yaml', 'iam.yaml') }
                  before(:each) { copy('%/iam.json', 'iam.json') }
                  before(:each) { run_command_and_stop('cfndk stack create') }
                  before(:each) { copy('%/vpc_different.yaml', 'vpc.yaml') }
                  before(:each) { copy('%/sg_different.yaml', 'sg.yaml') }
                  before(:each) { run_command('cfndk stack update --stack-names=Test Test2') }
                  it 'displays updated logs of Test1/Test2 stacks' do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO update.../)
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updating stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updated stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updating stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO updated stack: Test2-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO validate stack: Test3-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO updating stack: Test3-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO updated stack: Test3-#{uuid}$/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
              end
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
                expect(last_command_started).to have_output(/ERROR Template format error: At least one Resources member must be defined\.$/)
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
                expect(last_command_started).to have_output(/ERROR \[\/Resources\] 'null' values are not allowed in templates$/)
              end
            end
          end
        end
      end
      describe 'report', report: true do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk stack report') }
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

        context 'with cfndk.yml' do
          context 'when cfndk.yml is empty' do
            before(:each) { touch('cfndk.yml') }
            before(:each) { run_command('cfndk stack report') }
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
            before(:each) { run_command('cfndk stack report') }
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
                before(:each) { run_command('cfndk stack report') }
                it 'displays stacks report' do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO stack: Test$/)
                    expect(last_command_started).to have_output(/INFO stack: Test2$/)
                  end
                end
              end
              context 'when --stack-names Test2' do
                before(:each) { run_command('cfndk stack report --stack-names Test2') }
                it 'displays stacks report' do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).not_to have_output(/INFO stack: Test$/)
                    expect(last_command_started).to have_output(/INFO stack: Test2$/)
                  end
                end
              end
              context 'when --stack-names Test3' do
                before(:each) { run_command('cfndk stack report --stack-names Test3') }
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
                before(:each) { run_command('cfndk stack report -u 38437346-c75c-47c5-83b4-d504f85e275b') }
                it 'displays stacks report' do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO stack: Test-38437346-c75c-47c5-83b4-d504f85e275b$/)
                    expect(last_command_started).to have_output(/INFO stack: Test2-38437346-c75c-47c5-83b4-d504f85e275b$/)
                  end
                end
              end
              context 'when --stack-names Test2' do
                before(:each) { run_command('cfndk stack report -u 38437346-c75c-47c5-83b4-d504f85e275b --stack-names Test2') }
                it 'displays stacks report' do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).not_to have_output(/INFO stack: Test-38437346-c75c-47c5-83b4-d504f85e275b$/)
                    expect(last_command_started).to have_output(/INFO stack: Test2-38437346-c75c-47c5-83b4-d504f85e275b$/)
                  end
                end
              end
              context 'when --stack-names Test3' do
                before(:each) { run_command('cfndk stack report -u 38437346-c75c-47c5-83b4-d504f85e275b --stack-names Test3') }
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
end
