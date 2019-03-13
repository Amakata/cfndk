module CFnDK
  module SubcommandHelpReternable
    module ClassMethods
      def subcommand_help(cmd)
        desc 'help [COMMAND]', 'Describe subcommands or one specific subcommand'
        class_eval "
          def help(command = nil, subcommand = true); super; return 2; end
  "
      end
    end
    extend ClassMethods
    def self.included(klass)
      klass.extend ClassMethods
    end
  end

  module ConfigFileLoadable
    private

    def load_config_data(options)
      raise "File does not exist. #{options[:config_path]}" unless File.file?(options[:config_path])
      data = open(options[:config_path], 'r') { |f| YAML.load(f) }
      return data if data
      CFnDK.logger.error "File is empty. #{options[:config_path]}".color(:red)
      nil
    end
  end

  class KeyPairCommand < Thor
    include SubcommandHelpReternable
    include ConfigFileLoadable
    class_option :verbose, type: :boolean, aliases: 'v', desc: 'More verbose output.'
    class_option :color, type: :boolean, default: true, desc: 'Use colored output'
    class_option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    class_option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    class_option :keypair_names, type: :array, desc: 'Target keypair names'

    desc 'create', 'Create keypair'
    option :properties, type: :hash, aliases: 'p', default: {}, desc: 'Set property'
    def create
      CFnDK.logger.info 'create...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      keypairs = CFnDK::KeyPairs.new(data, options, credentials)
      keypairs.create
      return 0
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    desc 'destroy', 'Destroy keypair'
    option :force, type: :boolean, aliases: 'f', default: false, desc: 'Say yes to all prompts for confirmation'
    def destroy
      CFnDK.logger.info 'destroy...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      keypairs = CFnDK::KeyPairs.new(data, options, credentials)

      if options[:force] || yes?('Are you sure you want to destroy? (y/n)', :yellow)
        keypairs.destroy
        return 0
      else
        CFnDK.logger.info 'destroy command was canceled'.color(:green)
        return 2
      end
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end
  end

  class StackCommand < Thor
    include SubcommandHelpReternable
    include ConfigFileLoadable

    class_option :verbose, type: :boolean, aliases: 'v', desc: 'More verbose output.'
    class_option :color, type: :boolean, default: true, desc: 'Use colored output'
    class_option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    class_option :stack_names, type: :array, desc: 'Target stack names'

    desc 'create', 'Create stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :properties, type: :hash, aliases: 'p', default: {}, desc: 'Set property'
    def create
      CFnDK.logger.info 'create...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.validate
      stacks.create
      return 0
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    desc 'update', 'Update stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :properties, type: :hash, aliases: 'p', default: {}, desc: 'Set property'
    def update
      CFnDK.logger.info 'update...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.validate
      stacks.update
      return 0
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    desc 'destroy', 'Destroy stack'
    option :force, type: :boolean, aliases: 'f', default: false, desc: 'Say yes to all prompts for confirmation'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    def destroy
      CFnDK.logger.info 'destroy...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)

      if options[:force] || yes?('Are you sure you want to destroy? (y/n)', :yellow)
        stacks.destroy
        return 0
      else
        CFnDK.logger.info 'destroy command was canceled'.color(:green)
        return 2
      end
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    desc 'validate', 'Validate stack'
    def validate
      CFnDK.logger.info 'validate...'.color(:green)
      data = load_config_data(options)
      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.validate
      return 0
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    desc 'report', 'Report stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :types, type: :array, default: ['tag', 'output', 'parameter', 'resource', 'event'], desc: 'Report type'
    def report
      CFnDK.logger.info 'report...'.color(:green)
      data = load_config_data(options)
      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.report
      return 0
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end
  end

  class Command < Thor
    include Thor::Actions
    include ConfigFileLoadable
    class << self
      def exit_on_failure?
        true
      end
    end

    def help(command = nil, subcommand = false)
      super(command, subcommand)
      2
    end

    class_option :verbose, type: :boolean, aliases: 'v', desc: 'More verbose output.'
    class_option :color, type: :boolean, default: true, desc: 'Use colored output'

    desc 'generate-uuid', 'Print UUID'
    def generate_uuid
      puts SecureRandom.uuid
      0
    end

    desc 'version', 'Print version'
    def version
      puts CFnDK::VERSION
      0
    end

    desc 'init', 'Craete sample cfndk.yml & CloudFormation yaml & json files.'
    def init
      config_path = "#{Dir.getwd}/cfndk.yml"
      if File.file?(config_path)
        CFnDK.logger.error "File exist. #{config_path}".color(:red)
        return 1
      end
      CFnDK.logger.info 'init...'.color(:green)
      FileUtils.cp_r(Dir.glob(File.dirname(__FILE__) + '/../../skel/*'), './')
      CFnDK.logger.info "create #{config_path}".color(:green)
    end

    desc 'create', 'Create keypair & stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :properties, type: :hash, aliases: 'p', default: {}, desc: 'Set property'
    option :stack_names, type: :array, desc: 'Target stack names'
    option :keypair_names, type: :array, desc: 'Target keypair names'
    def create
      CFnDK.logger.info 'create...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      keypairs = CFnDK::KeyPairs.new(data, options, credentials)

      stacks.validate
      keypairs.create
      stacks.create
      return 0
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    desc 'destroy', 'Destroy keypair & stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    option :force, type: :boolean, aliases: 'f', default: false, desc: 'Say yes to all prompts for confirmation'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    def destroy
      CFnDK.logger.info 'destroy...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      keypairs = CFnDK::KeyPairs.new(data, options, credentials)

      if options[:force] || yes?('Are you sure you want to destroy? (y/n)', :yellow)
        stacks.destroy
        keypairs.destroy
        return 0
      else
        CFnDK.logger.info 'destroy command was canceled'.color(:green)
        return 2
      end
    rescue => e
      CFnDK.logger.error "(#{e.class}) #{e.message}".color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    desc 'report', 'Report stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :stack_names, type: :array, desc: 'Target stack names'
    option :types, type: :array, default: ['tag', 'output', 'parameter', 'resource', 'event'], desc: 'Report type'
    def report
      CFnDK.logger.info 'report...'.color(:green)

      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.report
      return 0
    rescue => e
      CFnDK.logger.error e.message.color(:red)
      CFnDK.logger.debug e.backtrace
      return 1
    end

    no_commands do
      def invoke_command(command, *args)
        CFnDK.logger = CFnDKLogger.new(options)
        Rainbow.enabled = false unless options[:color]
        super
      end
    end

    desc 'keypair SUBCOMMAND ...ARGS', 'Manage keypair'
    subcommand 'keypair', KeyPairCommand
    desc 'stack SUBCOMMAND ...ARGS', 'Manage stack'
    subcommand 'stack', StackCommand
  end
end
