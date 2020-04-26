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
    let(:pem) { 'test.pem' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }

    describe 'stack' do
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
            before(:each) { run_command('cfndk stack update') }
            it 'Displays error message and status code = 1' do
              aggregate_failures do
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                expect(last_command_started).to have_output(/ERROR Aws::CloudFormation::Errors::ValidationError: \[\/Resources\] 'null' values are not allowed in templates$/)
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
                  before(:each) { append_to_file('vpc.yaml', ' ' * (51200 + 1 - file_size('vpc.yaml').to_i)) }
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
              context 'with a stack and enabled is true' do
                yaml = <<-"YAML"
                stacks:
                  Test:
                    template_file: vpc.yaml
                    parameter_input: vpc.json
                    timeout_in_minutes: 2
                    enabled: true
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
                    before(:each) { append_to_file('vpc.yaml', ' ' * (51200 + 1 - file_size('vpc.yaml').to_i)) }
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
              end
              context 'with a stack and enabled is false', enabled: true do
                yaml = <<-"YAML"
                stacks:
                  Test:
                    template_file: vpc.yaml
                    parameter_input: vpc.json
                    timeout_in_minutes: 2
                    enabled: false
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
                        expect(last_command_started).to have_output(/INFO update...$/)
                        expect(last_command_started).not_to have_output(/INFO validate stack: Test$/)
                        expect(last_command_started).not_to have_output(/INFO updating stack: Test$/)
                        expect(last_command_started).not_to have_output(/WARN No updates are to be performed\.: Test$/)
                      end
                    end
                  end
                  context 'when different yaml' do
                    before(:each) { run_command_and_stop('cfndk stack create') }
                    before(:each) { copy('%/vpc_different.yaml', 'vpc.yaml') }
                    before(:each) { run_command('cfndk stack update') }
                    before(:each) { append_to_file('vpc.yaml', ' ' * (51200 + 1 - file_size('vpc.yaml').to_i)) }
                    it 'displays update log' do
                      aggregate_failures do
                        expect(last_command_started).to be_successfully_executed
                        expect(last_command_started).to have_output(/INFO update...$/)
                        expect(last_command_started).not_to have_output(/INFO validate stack: Test$/)
                        expect(last_command_started).not_to have_output(/INFO updating stack: Test$/)
                        expect(last_command_started).not_to have_output(/INFO updated stack: Test$/)
                      end
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
                    expect(last_command_started).to have_output(/ERROR Aws::CloudFormation::Errors::ValidationError: Stack \[Test\] does not exist$/)
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
                  expect(last_command_started).to have_output(/ERROR RuntimeError: There are cyclic dependency or stack doesn't exist. unprocessed_stack: Test,Test2$/)
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
                  expect(last_command_started).to have_output(/ERROR Aws::CloudFormation::Errors::InsufficientCapabilitiesException: Requires capabilities : \[CAPABILITY_NAMED_IAM\]/)
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
    end
  end
end
