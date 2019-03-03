require 'spec_helper'

RSpec.describe 'CFnDK Command', type: :aruba do
  let(:aws_region) { 'ap-northeast-1' }
  let(:aws_profile) { 'magento-cfn-ci' }
  before(:each) do
    Aruba.configure { |c| c.exit_timeout = 60 * 3 }
  end

  describe 'cfndk' do
    context 'when there are no command', help: true do
      before(:each) { run_command('cfndk') }
      it 'runs the command with the expected results' do
        aggregate_failures do
          expect(last_command_started).not_to be_successfully_executed
          expect(last_command_started).to have_exit_status(2)
        end
      end
    end

    context 'version', help: true do
      before(:each) { run_command('cfndk version') }
      it 'runs the command with the expected results' do
        aggregate_failures do
          expect(last_command_started).to be_successfully_executed
          expect(last_command_started).to have_output('0.0.7')
        end
      end
    end

    context 'generate-uuid', uuid: true do
      before(:each) { run_command('cfndk generate-uuid') }
      it 'runs the command with the expected results' do
        aggregate_failures do
          expect(last_command_started).to be_successfully_executed
          expect(last_command_started).to have_output(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
        end
      end
    end

    describe 'help', help: true do
      context 'when there are no subcommand)' do
        before(:each) { run_command('cfndk help') }
        it 'runs the command with the expected results' do
          aggregate_failures do
            expect(last_command_started).not_to be_successfully_executed
            expect(last_command_started).to have_exit_status(2)
          end
        end
      end

      context 'when uses version subcommand' do
        before(:each) { run_command('cfndk help version') }
        it 'runs the command with the expected results' do
          aggregate_failures do
            expect(last_command_started).not_to be_successfully_executed
            expect(last_command_started).to have_exit_status(2)
          end
        end
      end
    end

    describe 'init', init: true do
      before(:each) { setup_aruba }

      context 'when there are no cfndk.yml in work directory' do
        before(:each) { run_command('cfndk init') }
        it 'runs the command with the expected results' do
          aggregate_failures do
            expect(last_command_started).to be_successfully_executed
            expect(last_command_started).to have_output(/INFO init\.\.\..+INFO create .+cfndk.yml$/m)
          end
        end
      end

      context 'when there is cfndk.yml in work directory' do
        let(:file) { 'cfndk.yml' }
        before(:each) { touch(file) }
        before(:each) { run_command('cfndk init') }
        it 'runs the command with the expected results' do
          aggregate_failures do
            expect(last_command_started).not_to be_successfully_executed
            expect(last_command_started).to have_exit_status(1)
            expect(last_command_started).to have_output(/ERROR File exist./)
          end
        end
      end
    end

    describe 'create', create: true do
      before(:each) { setup_aruba }
      before(:each) { set_environment_variable('AWS_REGION', aws_region) }
      before(:each) { set_environment_variable('AWS_PROFILE', aws_profile) }

      context 'when there are no cfndk.yml in work directory' do
        before(:each) { run_command('cfndk create') }
        it 'runs the command with the expected results' do
          aggregate_failures do
            expect(last_command_started).not_to be_successfully_executed
            expect(last_command_started).to have_exit_status(1)
            expect(last_command_started).to have_output(/ERROR File does not exist./)
          end
        end
      end

      context 'when there is cfndk2.yml in work directory' do
        let(:file2) { 'cfndk2.yml' }
        context 'when -c cfndk2.yml is empty keypairs only' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          before(:each) { run_command("cfndk create -c=#{file2}") }
          it 'runs the command with the expected results' do
            aggregate_failures do
              expect(last_command_started).to be_successfully_executed
              expect(last_command_started).to have_output(/INFO create.../)
            end
          end
        end

        context 'when --config-path cfndk2.yml is empty keypairs only' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          before(:each) { run_command("cfndk create --config-path=#{file2}") }
          it 'runs the command with the expected results' do
            aggregate_failures do
              expect(last_command_started).to be_successfully_executed
              expect(last_command_started).to have_output(/INFO create.../)
            end
          end
        end
      end

      context 'when there is cfndk.yml in work directory' do
        let(:file) { 'cfndk.yml' }

        context 'when cfndk.yml is empty file' do
          before(:each) { touch(file) }
          before(:each) { run_command('cfndk create') }
          it 'runs the command with the expected results' do
            aggregate_failures do
              expect(last_command_started).not_to be_successfully_executed
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR File is empty./)
            end
          end
        end

        context 'when keyparis only', keypairs: true do
          context 'when empty keypairs ' do
            before(:each) { write_file(file, 'keypairs:') }
            before(:each) { run_command('cfndk create') }
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO create.../)
              end
            end
          end

          context 'when one keypair' do
            yaml = <<-"YAML"
            keypairs:
              Test:
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create') }
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO creating keypair: Test/)
                expect(last_command_started).to have_output(/INFO created keypair: Test/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end

          context 'when keypairs' do
            yaml = <<-"YAML"
            keypairs:
              Foo:
              Bar:
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create') }
            it 'runs the command with the expected results' do
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

          context 'when one keypair and key_file' do
            let(:pem) { 'test.pem' }
            yaml = <<-"YAML"
            keypairs:
              Test:
                key_file: test.pem
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create') }
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO creating keypair: Test/)
                expect(last_command_started).to have_output(/INFO created keypair: Test/)
                expect(last_command_started).to have_output(/create key file: #{pem}/)
                expect(pem).to be_an_existing_file
                expect(pem).to have_file_content(/-----END RSA PRIVATE KEY-----/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end

          context 'when -u 38437346-c75c-47c5-83b4-d504f85e275b and one keypair and use append_uuid' do
            let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }
            yaml = <<-"YAML"
            keypairs:
              Test:
                key_file: test<%= append_uuid %>.pem
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command("cfndk create -u=#{uuid}") }
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
            after(:each) { run_command("cfndk destroy -u=#{uuid} -f") }
          end

          context 'when unuse UUID and one keypair and use append_uuid' do
            let(:pem) { 'test.pem' }
            yaml = <<-"YAML"
            keypairs:
              Test:
                key_file: test<%= append_uuid %>.pem
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create') }
            it 'runs the command with the expected results' do
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

          context 'when CFNDK_UUID=38437346-c75c-47c5-83b4-d504f85e275b and one keypair' do
            let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }
            yaml = <<-"YAML"
            keypairs:
              Test:
                key_file: test<%= append_uuid %>.pem
            YAML
            before(:each) { set_environment_variable('CFNDK_UUID', uuid) }
            before(:each) { write_file(file, yaml) }
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
          context 'when --keypair-names=Test1 Test3' do
            yaml = <<-"YAML"
            keypairs:
              Test1:
              Test2:
              Test3:
            YAML
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create --keypair-names=Test1 Test3') }
            it 'runs the command with the expected results' do
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
          context 'when CFNDK_UUID=38437346-c75c-47c5-83b4-d504f85e275b and --keypair-names=Test1 Test3' do
            let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }
            yaml = <<-"YAML"
            keypairs:
              Test1:
              Test2:
              Test3:
            YAML
            before(:each) { set_environment_variable('CFNDK_UUID', uuid) }
            before(:each) { write_file(file, yaml) }
            before(:each) { run_command('cfndk create --keypair-names=Test1 Test3') }
            it 'runs the command with the expected results' do
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

        context 'when stacks only', stacks: true do
          context 'when empty stacks' do
            before(:each) { write_file(file, 'stacks:') }
            before(:each) { run_command('cfndk create') }
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO create.../)
              end
            end
          end

          context 'when one stack' do
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
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO validate stack: Test$/)
                expect(last_command_started).to have_output(/INFO creating stack: Test$/)
                expect(last_command_started).to have_output(/INFO created stack: Test$/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end
          context 'when two stacks' do
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
            it 'runs the command with the expected results' do
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
          context 'when two stacks and invalid depends' do
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
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).not_to be_successfully_executed
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/ERROR stopped waiting, encountered a failure state$/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end
          context 'when two stacks and cyclic dependency', cyclic: true do
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
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).not_to be_successfully_executed
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/ERROR There are cyclic dependency or stack doesn't exist. unprocessed_stack: Test,Test2$/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end
          context 'when iam and no capabilities', capabilities: true do
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
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).not_to be_successfully_executed
                expect(last_command_started).to have_exit_status(1)
                expect(last_command_started).to have_output(/ERROR Requires capabilities : \[CAPABILITY_NAMED_IAM\]/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end
          context 'when iam and capabilities', capabilities: true do
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
            it 'runs the command with the expected results' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO created stack: Test$/)
              end
            end
            after(:each) { run_command('cfndk destroy -f') }
          end
          context 'when -u 38437346-c75c-47c5-83b4-d504f85e275b and two stacks and use append_uuid', uuid: true do
            let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }
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
            it 'runs the command with the expected results' do
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
        end
      end
    end
  end
end
