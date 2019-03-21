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
      describe 'create', create: true do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk changeset create') }
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
            before(:each) { run_command("cfndk changeset create -c=#{file2}") }
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
            before(:each) { run_command('cfndk changeset create') }
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
              before(:each) { run_command('cfndk changeset create') }
              it 'displays create log' do
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
              before(:each) { append_to_file('vpc.yaml', ' ' * (51200 + 1 - file_size('vpc.yaml').to_i)) }
              before(:each) { run_command('cfndk changeset create') }
              it 'displays created log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating change set: Test$/)
                  expect(last_command_started).to have_output(/INFO created change set: Test$/)
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
              before(:each) { run_command('cfndk changeset create') }
              it 'displays created logs' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating change set: Test$/)
                  expect(last_command_started).to have_output(/INFO created change set: Test$/)
                  expect(last_command_started).to have_output(/INFO validate stack: Test2$/)
                  expect(last_command_started).to have_output(/INFO creating change set: Test2$/)
                  expect(last_command_started).to have_output(/INFO created change set: Test2$/)
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
              before(:each) { run_command('cfndk changeset create') }
              it 'displays created logs' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating change set: Test$/)
                  expect(last_command_started).to have_output(/INFO created change set: Test$/)
                  expect(last_command_started).to have_output(/INFO validate stack: Test2$/)
                  expect(last_command_started).to have_output(/INFO creating change set: Test2$/)
                  expect(last_command_started).to have_output(/INFO created change set: Test2$/)
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
              before(:each) { run_command('cfndk changeset create') }
              it 'displays cyclic dependency error and exit code = 1' do
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
                  timeout_in_minutes: 2
              YAML

              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/iam.yaml', 'iam.yaml') }
              before(:each) { copy('%/iam.json', 'iam.json') }
              before(:each) { run_command('cfndk changeset create') }
              it 'displays Requires capabilities error and exit code = 1' do
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
              before(:each) { run_command('cfndk changeset create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO created change set: Test$/)
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
                before(:each) { run_command("cfndk changeset create -u=#{uuid}") }
                it do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO creating change set: Test$/)
                    expect(last_command_started).to have_output(/INFO created change set: Test$/)
                    expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO creating change set: Test2$/)
                    expect(last_command_started).to have_output(/INFO created change set: Test2$/)
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
                  before(:each) { run_command('cfndk changeset create') }
                  it do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating change set: Test$/)
                      expect(last_command_started).to have_output(/INFO created change set: Test$/)
                      expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating change set: Test2$/)
                      expect(last_command_started).to have_output(/INFO created change set: Test2$/)
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
                  before(:each) { run_command('cfndk changeset create --stack-names=Test') }
                  it do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO create.../)
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating change set: Test$/)
                      expect(last_command_started).to have_output(/INFO created change set: Test$/)
                      expect(last_command_started).not_to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO creating change set: Test2$/)
                      expect(last_command_started).not_to have_output(/INFO created change set: Test2$/)
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
                  before(:each) { run_command('cfndk changeset create --stack-names=Test Test2') }
                  it do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO create.../)
                      expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating change set: Test$/)
                      expect(last_command_started).to have_output(/INFO created change set: Test$/)
                      expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                      expect(last_command_started).to have_output(/INFO creating change set: Test2$/)
                      expect(last_command_started).to have_output(/INFO created change set: Test2$/)
                      expect(last_command_started).not_to have_output(/INFO validate stack: Test3-#{uuid}$/)
                      expect(last_command_started).not_to have_output(/INFO creating change set: Test3$/)
                      expect(last_command_started).not_to have_output(/INFO created change set: Test3$/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
              end

              context 'when -u 38437346-c75c-47c5-83b4-d504f85e275b and --change-set-uuid 38437346-c75c-47c5-83b4-d504f85e275c' do
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
                before(:each) { run_command("cfndk changeset create -u=#{uuid} --change-set-uuid 38437346-c75c-47c5-83b4-d504f85e275c") }
                it do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO validate stack: Test-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO creating change set: Test-38437346-c75c-47c5-83b4-d504f85e275c$/)
                    expect(last_command_started).to have_output(/INFO created change set: Test-38437346-c75c-47c5-83b4-d504f85e275c$/)
                    expect(last_command_started).to have_output(/INFO validate stack: Test2-#{uuid}$/)
                    expect(last_command_started).to have_output(/INFO creating change set: Test2-38437346-c75c-47c5-83b4-d504f85e275c$/)
                    expect(last_command_started).to have_output(/INFO created change set: Test2-38437346-c75c-47c5-83b4-d504f85e275c$/)
                  end
                end
                after(:each) { run_command("cfndk destroy -f -u=#{uuid}") }
              end
            end
          end
        end
      end
    end
  end
end
