require 'spec_helper'

RSpec.describe 'CFnDK Command', type: :aruba do
  describe 'cfndk' do
    context '(no option)' do
      before(:each) { run_command('cfndk') }
      it { expect(last_command_started).not_to be_successfully_executed }
      it { expect(last_command_started).to have_exit_status(2) }
    end

    context 'version' do
      before(:each) { run_command('cfndk version') }
      it { expect(last_command_started).to be_successfully_executed }
      it { expect(last_command_started).to have_output('0.0.6') }
    end

    context 'generate-uuid' do
      before(:each) { run_command('cfndk generate-uuid') }
      it { expect(last_command_started).to be_successfully_executed }
      it { expect(last_command_started).to have_output(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/) }
    end

    describe 'help' do
      context '(no option)' do
        before(:each) { run_command('cfndk help') }
        it { expect(last_command_started).not_to be_successfully_executed }
        it { expect(last_command_started).to have_exit_status(2) }
      end

      context 'version' do
        before(:each) { run_command('cfndk help version') }
        it { expect(last_command_started).not_to be_successfully_executed }
        it { expect(last_command_started).to have_exit_status(2) }
      end
    end

    describe 'init' do
      context 'there are no cfndk.yml in work directory' do
        before(:each) { setup_aruba }
        before(:each) { run_command('cfndk init'); }
        it { expect(last_command_started).to be_successfully_executed }
        it { expect(last_command_started).to have_output(/INFO init\.\.\..+INFO create .+cfndk.yml$/m) }
      end
      context 'there is cfndk.yml in work directory' do
        let(:file) { 'cfndk.yml' }
        before(:each) { setup_aruba }
        before(:each) { touch(file) }
        before(:each) { run_command('cfndk init') }
        it { expect(last_command_started).not_to be_successfully_executed }
        it { expect(last_command_started).to have_output(/ERROR File exist./) }
      end
    end
  end
end
