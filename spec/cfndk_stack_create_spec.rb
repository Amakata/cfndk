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
              global:
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
            context 'with a 51200byte template stack' do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/big_vpc.yaml', 'vpc.yaml') }
              before(:each) { copy('%/vpc.json', 'vpc.json') }
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).not_to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates})
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with a 51201byte template stack', big: true, bigbig: true do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/big_vpc.yaml', 'vpc.yaml') }
              before(:each) { copy('%/vpc.json', 'vpc.json') }
              before(:each) { append_to_file('vpc.yaml', '1') }
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates})
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with stack and nested stack', nested: true do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
                  package: true
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/stack.yaml', 'vpc.yaml') }
              before(:each) { copy('%/stack.json', 'vpc.json') }
              before(:each) { copy('%/nested_stack.yaml', 'nested_stack.yaml') }
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates/.+/nested_stack.yaml})
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with stack with directory and nested stack', directory_nested: true do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: vpc/vpc.yaml
                  parameter_input: vpc/vpc.json
                  timeout_in_minutes: 2
                  package: true
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/stack.yaml', 'vpc/vpc.yaml') }
              before(:each) { copy('%/stack.json', 'vpc/vpc.json') }
              before(:each) { copy('%/nested_stack.yaml', 'vpc/nested_stack.yaml') }
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates/.+/nested_stack.yaml})
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end            
            context 'with a 51201byte template stack and nested stack', nested: true, big: true, nested_big: true  do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: vpc.yaml
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
                  package: true
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/stack.yaml', 'vpc.yaml') }
              before(:each) { copy('%/stack.json', 'vpc.json') }
              before(:each) { copy('%/nested_stack.yaml', 'nested_stack.yaml') }
              before(:each) { 
                append_to_file('vpc.yaml',  "\nOutputs:\n")
                for number in 1..40 do
                  stack_append = <<-"YAML"
                    VpcId012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345#{number.to_s}:
                      Description: 01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678901234567890123
                      Value: !Ref Vpc
                      Export:
                        Name: !Sub ${VpcName}-VpcId012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345#{number.to_s}
                  YAML
                  append_to_file('vpc.yaml',  stack_append)
                  # p read('vpc.yaml').join("\n").length
                end
              }
              before(:each) { append_to_file('nested_stack.yaml', "\n" +  '#' * (51200 + 1 - 2 - file_size('nested_stack.yaml').to_i)) }                            
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates/.+/vpc.yaml})
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates/.+/nested_stack.yaml})
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with json stack and json nested stack', nested: true, json: true do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: vpc.template.json
                  parameter_input: vpc.json
                  timeout_in_minutes: 2
                  package: true
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/stack.template.json', 'vpc.template.json') }
              before(:each) { copy('%/stack.json', 'vpc.json') }
              before(:each) { copy('%/nested_stack.json', 'nested_stack.json') }
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates/.+/nested_stack.json})
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with lambda function and zip file', lambda_function: true do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: lambda_function.yaml
                  parameter_input: lambda_function.json
                  timeout_in_minutes: 2
                  capabilities:
                    - CAPABILITY_IAM
                  package: true
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/lambda_function/lambda_function.yaml', 'lambda_function.yaml') }
              before(:each) { copy('%/lambda_function/lambda_function.json', 'lambda_function.json') }
              before(:each) { copy('%/lambda_function/index.js', 'lambda_function/index.js') }
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates/.+/lambda_function.zip})
                end
              end
              after(:each) { run_command('cfndk destroy -f') }
            end
            context 'with serverless function and zip file', serverless_function: true do
              yaml = <<-"YAML"
              global:
              stacks:
                Test:
                  template_file: serverless_function.yaml
                  parameter_input: serverless_function.json
                  timeout_in_minutes: 2
                  capabilities:
                    - CAPABILITY_AUTO_EXPAND
                    - CAPABILITY_IAM
                  package: true
              YAML
              before(:each) { write_file(file, yaml) }
              before(:each) { copy('%/serverless_function/serverless_function.yaml', 'serverless_function.yaml') }
              before(:each) { copy('%/serverless_function/serverless_function.json', 'serverless_function.json') }
              before(:each) { copy('%/serverless_function/index.js', 'serverless_function/index.js') }
              before(:each) { run_command('cfndk stack create') }
              it 'displays created stack log' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                  expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                  expect(last_command_started).to have_output(/INFO created stack: Test$/)
                  expect(last_command_started).to have_output(%r{INFO Put S3 object: https://s3.amazonaws.com/[0-9]+-ap-northeast-1-cfndk-templates/.+/serverless_function.zip})
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
                  expect(last_command_started).to have_output(/ERROR Aws::Waiters::Errors::FailureStateError: stopped waiting, encountered a failure state$/)
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
              before(:each) { run_command('cfndk stack create') }
              it do
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
    end
  end
end
