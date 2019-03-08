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

    describe 'create', create: true do
      context 'without cfndk.yml' do
        before(:each) { run_command('cfndk create') }
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
        context 'when -c cfndk2.yml and empty keypairs' do
          before(:each) { run_command("cfndk create -c=#{file2}") }
          it do
            aggregate_failures do
              expect(last_command_started).to be_successfully_executed
              expect(last_command_started).to have_output(/INFO create.../)
            end
          end
        end

        context 'when --config-path cfndk2.yml and empty keypairs' do
          before(:each) { run_command("cfndk create --config-path=#{file2}") }
          it do
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
          before(:each) { run_command('cfndk create') }
          it 'displays File is empty error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File is empty./)
            end
          end
        end

        context 'with keyparis:', keypairs: true do
          context 'without keypair' do
            before(:each) { write_file(file, 'keypairs:') }
            before(:each) { run_command('cfndk create') }
            it do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO create.../)
              end
            end
          end

          context 'with a keypair' do
            yaml = <<-"YAML"
            keypairs:
              Test:
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create') }
            it do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO creating keypair: Test/)
                expect(last_command_started).to have_output(/INFO created keypair: Test/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end

          context 'with two keypairs' do
            yaml = <<-"YAML"
            keypairs:
              Foo:
              Bar:
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create') }
            it do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO creating keypair: Foo/)
                expect(last_command_started).to have_output(/INFO created keypair: Foo/)
                expect(last_command_started).to have_output(/INFO creating keypair: Bar/)
                expect(last_command_started).to have_output(/INFO created keypair: Bar/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end

          context 'with a keypair and a key_file' do
            context 'without UUID', uuid: true do
              context 'without append_uuid' do
                yaml = <<-"YAML"
                keypairs:
                  Test:
                    key_file: test.pem
                YAML
                before(:each) { write_file(file, yaml) }
                before(:each) { run_command('cfndk create') }
                it do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO create.../)
                    expect(last_command_started).to have_output(/INFO creating keypair: Test$/)
                    expect(last_command_started).to have_output(/INFO created keypair: Test$/)
                    expect(last_command_started).to have_output(/create key file: #{pem}$/)
                    expect(pem).to be_an_existing_file
                    expect(pem).to have_file_content(/-----END RSA PRIVATE KEY-----/)
                  end
                end
                after(:each) { run_command('cfndk destroy -f') }
              end

              context 'with append_uuid' do
                yaml = <<-"YAML"
                keypairs:
                  Test:
                    key_file: test<%= append_uuid %>.pem
                YAML
                before(:each) { write_file(file, yaml) }
                before(:each) { run_command('cfndk create') }
                it do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO create.../)
                    expect(last_command_started).to have_output(/INFO creating keypair: Test$/)
                    expect(last_command_started).to have_output(/INFO created keypair: Test$/)
                    expect(last_command_started).to have_output(/create key file: #{pem}/)
                    expect(pem).to be_an_existing_file
                    expect(pem).to have_file_content(/-----END RSA PRIVATE KEY-----/)
                  end
                end
                after(:each) { run_command('cfndk destroy -f') }
              end
            end

            context 'with UUID', uuid: true do
              yaml = <<-"YAML"
              keypairs:
                Test:
                  key_file: test<%= append_uuid %>.pem
              YAML
              before(:each) { write_file(file, yaml) }
              context 'when -u 38437346-c75c-47c5-83b4-d504f85e275b' do
                before(:each) { run_command("cfndk create -u=#{uuid}") }
                it do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO create.../)
                    expect(last_command_started).to have_output(/INFO creating keypair: Test-#{uuid}/)
                    expect(last_command_started).to have_output(/INFO created keypair: Test-#{uuid}/)
                    expect(last_command_started).to have_output(/create key file: test-#{uuid}.pem/)
                    expect("test-#{uuid}.pem").to be_an_existing_file
                    expect("test-#{uuid}.pem").to have_file_content(/-----END RSA PRIVATE KEY-----/)
                  end
                end
                after(:each) { run_command("cfndk destroy -u=#{uuid} -f") }
              end

              context 'when env CFNDK_UUID=38437346-c75c-47c5-83b4-d504f85e275b' do
                before(:each) { set_environment_variable('CFNDK_UUID', uuid) }
                before(:each) { run_command('cfndk create') }
                it 'runs the command with the expected results' do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO create.../)
                    expect(last_command_started).to have_output(/INFO creating keypair: Test-#{uuid}/)
                    expect(last_command_started).to have_output(/INFO created keypair: Test-#{uuid}/)
                    expect(last_command_started).to have_output(/create key file: test-#{uuid}.pem/)
                    expect("test-#{uuid}.pem").to be_an_existing_file
                    expect("test-#{uuid}.pem").to have_file_content(/-----END RSA PRIVATE KEY-----/)
                  end
                end
                after(:each) { run_command('cfndk destroy -f') }
              end
            end
          end
          context 'with keypairs' do
            yaml = <<-"YAML"
            keypairs:
              Test1:
              Test2:
              Test3:
            YAML
            before(:each) { write_file(file, yaml) }
            context 'when --keypair-names=Test1 Test3' do
              context 'without UUID' do
                before(:each) { run_command('cfndk create --keypair-names=Test1 Test3') }
                it do
                  aggregate_failures do
                    expect(last_command_started).to be_successfully_executed
                    expect(last_command_started).to have_output(/INFO create.../)
                    expect(last_command_started).to have_output(/INFO creating keypair: Test1/)
                    expect(last_command_started).to have_output(/INFO created keypair: Test1/)
                    expect(last_command_started).not_to have_output(/INFO creating keypair: Test2/)
                    expect(last_command_started).not_to have_output(/INFO created keypair: Test2/)
                    expect(last_command_started).to have_output(/INFO creating keypair: Test3/)
                    expect(last_command_started).to have_output(/INFO created keypair: Test3/)
                  end
                end
                after(:each) { run_command('cfndk destroy -f') }
              end
              context 'with UUID' do
                context 'when env CFNDK_UUID=38437346-c75c-47c5-83b4-d504f85e275b' do
                  before(:each) { set_environment_variable('CFNDK_UUID', uuid) }
                  before(:each) { run_command('cfndk create --keypair-names=Test1 Test3') }
                  it do
                    aggregate_failures do
                      expect(last_command_started).to be_successfully_executed
                      expect(last_command_started).to have_output(/INFO create.../)
                      expect(last_command_started).to have_output(/INFO creating keypair: Test1-#{uuid}/)
                      expect(last_command_started).to have_output(/INFO created keypair: Test1-#{uuid}/)
                      expect(last_command_started).not_to have_output(/INFO creating keypair: Test2-#{uuid}/)
                      expect(last_command_started).not_to have_output(/INFO created keypair: Test2-#{uuid}/)
                      expect(last_command_started).to have_output(/INFO creating keypair: Test3-#{uuid}/)
                      expect(last_command_started).to have_output(/INFO created keypair: Test3-#{uuid}/)
                    end
                  end
                  after(:each) { run_command('cfndk destroy -f') }
                end
              end
            end
          end
        end

        context 'with stacks:', stacks: true do
          context 'without stack' do
            before(:each) { write_file(file, 'stacks:') }
            before(:each) { run_command('cfndk create') }
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
            before(:each) { run_command('cfndk create') }
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
            before(:each) { run_command('cfndk create') }
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
            before(:each) { run_command('cfndk create') }
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
            before(:each) { run_command('cfndk create') }
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
            before(:each) { run_command('cfndk create') }
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
            before(:each) { run_command('cfndk create') }
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
              before(:each) { run_command("cfndk create -u=#{uuid}") }
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
                before(:each) { run_command('cfndk create') }
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
                before(:each) { run_command('cfndk create --stack-names=Test') }
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
                before(:each) { run_command('cfndk create --stack-names=Test Test2') }
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
