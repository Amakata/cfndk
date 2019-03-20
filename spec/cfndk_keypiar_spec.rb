require 'spec_helper'

RSpec.describe 'CFnDK', type: :aruba do
  before(:each) { set_environment_variable('AWS_REGION', ENV['AWS_REGION'] + ENV['TEST_ENV_NUMBER']) }
  before(:each) { set_environment_variable('AWS_PROFILE', ENV['AWS_PROFILE'] + ENV['TEST_ENV_NUMBER']) }
  before(:each) { set_environment_variable('AWS_ACCESS_KEY_ID', ENV['AWS_ACCESS_KEY_ID'] + ENV['TEST_ENV_NUMBER']) }
  before(:each) { set_environment_variable('AWS_SECRET_ACCESS_KEY', ENV['AWS_SECRET_ACCESS_KEY'] + ENV['TEST_ENV_NUMBER']) }
  describe 'bin/cfndk' do
    before(:each) { setup_aruba }
    let(:file) { 'cfndk.yml' }
    let(:file2) { 'cfndk2.yml' }
    let(:pem) { 'test.pem' }
    let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }

    describe 'keypair' do
      context 'without subcommand', help: true do
        before(:each) { run_command('cfndk keypair') }
        it 'displays help and status code = 2' do
          aggregate_failures do
            expect(last_command_started).to have_exit_status(2)
          end
        end
      end

      describe 'help', help: true do
        context 'without subsubcommand' do
          before(:each) { run_command('cfndk keypair help') }
          it 'displays help and status code = 2' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(2)
            end
          end
        end
      end

      describe 'create' do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk keypair create') }
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
          context 'when -c cfndk2.yml and empty keypairs' do
            before(:each) { run_command("cfndk keypair create -c=#{file2}") }
            it 'displays empty keypair log' do
              aggregate_failures do
                expect(last_command_started).to be_successfully_executed
                expect(last_command_started).to have_output(/INFO create.../)
              end
            end
          end

          context 'when --config-path cfndk2.yml and empty keypairs' do
            before(:each) { run_command("cfndk keypair create --config-path=#{file2}") }
            it 'displays empty keypair log' do
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
            before(:each) { run_command('cfndk keypair create') }
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
              before(:each) { run_command('cfndk keypair create') }
              it do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO create.../)
                end
              end
            end

            context 'with stacks:' do
              before(:each) { write_file(file, 'stacks:') }
              before(:each) { run_command('cfndk keypair create') }
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
              before(:each) { run_command('cfndk keypair create') }
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
              before(:each) { run_command('cfndk keypair create') }
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
                  before(:each) { run_command('cfndk keypair create') }
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
                  before(:each) { run_command('cfndk keypair create') }
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
                  before(:each) { run_command("cfndk keypair create -u=#{uuid}") }
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
                  before(:each) { run_command('cfndk keypair create') }
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
                  before(:each) { run_command('cfndk keypair create --keypair-names=Test1 Test3') }
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
                    before(:each) { run_command('cfndk keypair create --keypair-names=Test1 Test3') }
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
        end
      end

      describe 'destroy' do
        context 'without cfndk.yml' do
          before(:each) { run_command('cfndk keypair destroy') }
          it 'displays file does not exist error and status code = 1' do
            aggregate_failures do
              expect(last_command_started).to have_exit_status(1)
              expect(last_command_started).to have_output(/ERROR RuntimeError: File does not exist./)
            end
          end
        end
        context 'with cfndk.yml' do
          context 'when cfndk.yml is empty' do
            before(:each) { touch(file) }
            before(:each) { run_command('cfndk keypair destroy -f') }
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
            before(:each) { run_command('cfndk keypair destroy') }
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
            context 'when keyparis do not exist' do
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
              before(:each) { run_command_and_stop('cfndk destroy -f') }
              before(:each) { run_command('cfndk keypair destroy') }
              before(:each) { type('yes') }
              it 'displays confirm message and do not delete message' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO destroy../)
                  expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                  expect(last_command_started).to have_output(/INFO do not delete keypair: Test1$/)
                  expect(last_command_started).not_to have_output(/INFO do not delete stack: Test$/)
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
              before(:each) { run_command('cfndk keypair destroy') }
              before(:each) { type('yes') }
              it 'displays confirm message and delete message' do
                aggregate_failures do
                  expect(last_command_started).to be_successfully_executed
                  expect(last_command_started).to have_output(/INFO destroy../)
                  expect(last_command_started).to have_output(%r{Are you sure you want to destroy\? \(y/n\)})
                  expect(last_command_started).to have_output(/INFO deleted keypair: Test1$/)
                  expect(last_command_started).not_to have_output(/INFO deleted stack: Test$/)
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
