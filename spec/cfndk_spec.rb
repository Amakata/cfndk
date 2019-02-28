require 'spec_helper'

RSpec.describe 'CFnDK Command', type: :aruba do
  let(:aws_region) { 'ap-northeast-1' }
  let(:aws_profile) { 'magento-cfn-ci' }
  describe 'cfndk' do
    context 'when there are no command', help: true do
      before(:each) { run_command('cfndk') }
      it { expect(last_command_started).not_to be_successfully_executed }
      it { expect(last_command_started).to have_exit_status(2) }
    end

    context 'version', help: true do
      before(:each) { run_command('cfndk version') }
      it { expect(last_command_started).to be_successfully_executed }
      it { expect(last_command_started).to have_output('0.0.7') }
    end

    context 'generate-uuid', uuid: true do
      before(:each) { run_command('cfndk generate-uuid') }
      it { expect(last_command_started).to be_successfully_executed }
      it { expect(last_command_started).to have_output(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/) }
    end

    describe 'help', help: true do
      context 'when there are no subcommand)' do
        before(:each) { run_command('cfndk help') }
        it { expect(last_command_started).not_to be_successfully_executed }
        it { expect(last_command_started).to have_exit_status(2) }
      end

      context 'when uses version subcommand' do
        before(:each) { run_command('cfndk help version') }
        it { expect(last_command_started).not_to be_successfully_executed }
        it { expect(last_command_started).to have_exit_status(2) }
      end
    end

    describe 'init', init: true do
      before(:each) { setup_aruba }

      context 'when there are no cfndk.yml in work directory' do
        before(:each) { run_command('cfndk init') }
        it { expect(last_command_started).to be_successfully_executed }
        it { expect(last_command_started).to have_output(/INFO init\.\.\..+INFO create .+cfndk.yml$/m) }
      end

      context 'when there is cfndk.yml in work directory' do
        let(:file) { 'cfndk.yml' }
        before(:each) { touch(file) }
        before(:each) { run_command('cfndk init') }
        it { expect(last_command_started).not_to be_successfully_executed }
        it { expect(last_command_started).to have_output(/ERROR File exist./) }
      end
    end

    describe 'create', create: true do
      before(:each) { setup_aruba }
      before(:each) { set_environment_variable('AWS_REGION', aws_region) }
      before(:each) { set_environment_variable('AWS_PROFILE', aws_profile) }

      context 'when there are no cfndk.yml in work directory' do
        before(:each) { run_command('cfndk create') }
        it { expect(last_command_started).not_to be_successfully_executed }
        it { expect(last_command_started).to have_output(/ERROR File does not exist./m) }
      end

      context 'when there is cfndk2.yml in work directory' do
        let(:file2) { 'cfndk2.yml' }
        context 'when -c cfndk2.yml is empty keypairs only' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          before(:each) { run_command("cfndk create -c #{file2}") }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../) }
        end

        context 'when --config-path cfndk2.yml is empty keypairs only' do
          yaml = <<-"YAML"
          keypairs:
          YAML
          before(:each) { write_file(file2, yaml) }
          before(:each) { run_command("cfndk create --config-path #{file2}") }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../) }
        end
      end

      context 'when there is cfndk.yml in work directory' do
        let(:file) { 'cfndk.yml' }

        context 'when cfndk.yml is empty file' do
          before(:each) { touch(file) }
          before(:each) { run_command('cfndk create') }
          it { expect(last_command_started).not_to be_successfully_executed }
          it { expect(last_command_started).to have_output(/ERROR File is empty./m) }
        end

        context 'when cfndk.yml is empty keypairs only' do
          before(:each) { write_file(file, 'keypairs:') }
          before(:each) { run_command('cfndk create') }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../m) }
        end

        context 'when cfndk.yml is empty stacks only' do
          before(:each) { write_file(file, 'stacks:') }
          before(:each) { run_command('cfndk create') }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../m) }
        end

        context 'when cfndk.yml is keypairs and one keypair' do
          yaml = <<-"YAML"
          keypairs:
            Test:
          YAML
          before(:each) { write_file(file, yaml) }
          before(:each) { run_command('cfndk create') }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test/) }
          after(:each) { run_command('cfndk destroy -f') }
        end

        context 'when cfndk.yml is keypairs and keypairs' do
          yaml = <<-"YAML"
          keypairs:
            Foo:
            Bar:
          YAML
          before(:each) { write_file(file, yaml) }
          before(:each) { run_command('cfndk create') }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Foo/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Foo/) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Bar/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Bar/) }
          after(:each) { run_command('cfndk destroy -f') }
        end

        context 'when cfndk.yml is keypairs and one keypair and key_file' do
          let(:pem) { 'test.pem' }
          yaml = <<-"YAML"
          keypairs:
            Test:
              key_file: test.pem
          YAML
          before(:each) { write_file(file, yaml) }
          before(:each) { run_command('cfndk create') }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test/) }
          it { expect(last_command_started).to have_output(/create key file: #{pem}/) }
          it { expect(pem).to be_an_existing_file }
          it { expect(pem).to have_file_content(/-----END RSA PRIVATE KEY-----/) }
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
          before(:each) { run_command("cfndk create -u #{uuid}") }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test-#{uuid}/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test-#{uuid}/) }
          it { expect(last_command_started).to have_output(/create key file: test-#{uuid}.pem/) }
          it { expect("test-#{uuid}.pem").to be_an_existing_file }
          it { expect("test-#{uuid}.pem").to have_file_content(/-----END RSA PRIVATE KEY-----/) }
          after(:each) { run_command("cfndk destroy -u #{uuid} -f") }
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
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test$/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test$/) }
          it { expect(last_command_started).to have_output(/create key file: #{pem}/) }
          it { expect(pem).to be_an_existing_file }
          it { expect(pem).to have_file_content(/-----END RSA PRIVATE KEY-----/) }
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
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test-#{uuid}/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test-#{uuid}/) }
          it { expect(last_command_started).to have_output(/create key file: test-#{uuid}.pem/) }
          it { expect("test-#{uuid}.pem").to be_an_existing_file }
          it { expect("test-#{uuid}.pem").to have_file_content(/-----END RSA PRIVATE KEY-----/) }
          after(:each) { run_command('cfndk destroy -f') }
        end
        context 'when --keypair-names Test1 Test3' do
          yaml = <<-"YAML"
          keypairs:
            Test1:
            Test2:
            Test3:
          YAML
          before(:each) { write_file(file, yaml) }
          before(:each) { run_command('cfndk create --keypair-names Test1 Test3') }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test1/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test1/) }
          it { expect(last_command_started).not_to have_output(/INFO creating keypair: Test2/) }
          it { expect(last_command_started).not_to have_output(/INFO created keypair: Test2/) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test3/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test3/) }
          after(:each) { run_command('cfndk destroy -f') }
        end
        context 'when CFNDK_UUID=38437346-c75c-47c5-83b4-d504f85e275b and --keypair-names Test1 Test3' do
          let(:uuid) { '38437346-c75c-47c5-83b4-d504f85e275b' }
          yaml = <<-"YAML"
          keypairs:
            Test1:
            Test2:
            Test3:
          YAML
          before(:each) { set_environment_variable('CFNDK_UUID', uuid) }
          before(:each) { write_file(file, yaml) }
          before(:each) { run_command('cfndk create --keypair-names Test1 Test3') }
          it { expect(last_command_started).to be_successfully_executed }
          it { expect(last_command_started).to have_output(/INFO create.../) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test1-#{uuid}/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test1-#{uuid}/) }
          it { expect(last_command_started).not_to have_output(/INFO creating keypair: Test2-#{uuid}/) }
          it { expect(last_command_started).not_to have_output(/INFO created keypair: Test2-#{uuid}/) }
          it { expect(last_command_started).to have_output(/INFO creating keypair: Test3-#{uuid}/) }
          it { expect(last_command_started).to have_output(/INFO created keypair: Test3-#{uuid}/) }
          after(:each) { run_command('cfndk destroy -f') }
        end
      end
    end
  end
end
