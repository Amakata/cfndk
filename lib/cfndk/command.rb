module CFnDK
  class KeyPairCommand < Thor
    class_option :verbose, type: :boolean, aliases: 'v'
    class_option :color, type: :boolean, default: true
    class_option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml"
    class_option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
    class_option :keypair_names, type: :array

    desc 'create', 'create keypair'
    option :properties, type: :hash, aliases: 'p', default: {}
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

    desc 'destroy', 'destroy keypair'
    option :force, type: :boolean, aliases: 'f', default: false
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

    private

    def load_config_data(options)
      raise "File does not exist. #{options[:config_path]}" unless File.file?(options[:config_path])
      data = open(options[:config_path], 'r') { |f| YAML.load(f) }
      return data if data
      CFnDK.logger.error "File is empty. #{options[:config_path]}".color(:red)
      nil
    end
  end

  class StackCommand < Thor
    class_option :verbose, type: :boolean, aliases: 'v'
    class_option :color, type: :boolean, default: true
    class_option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml"
    class_option :stack_names, type: :array


    desc 'create', 'create stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
    option :properties, type: :hash, aliases: 'p', default: {}
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

    desc 'update', 'update stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
    option :properties, type: :hash, aliases: 'p', default: {}
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

    desc 'destroy', 'destroy stack'
    option :force, type: :boolean, aliases: 'f', default: false
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
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

    desc 'validate', 'validate stack'
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

    desc 'report', 'report stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
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

    private

    def load_config_data(options)
      raise "File does not exist. #{options[:config_path]}" unless File.file?(options[:config_path])
      data = open(options[:config_path], 'r') { |f| YAML.load(f) }
      return data if data
      CFnDK.logger.error "File is empty. #{options[:config_path]}".color(:red)
      nil
    end
  end

  class Command < Thor
    include Thor::Actions
    class << self
      def exit_on_failure?
        true
      end
    end

    def help(command = nil, subcommand = false)
      super(command, subcommand)
      2
    end

    class_option :verbose, type: :boolean, aliases: 'v'
    class_option :color, type: :boolean, default: true

    desc 'generate-uuid', 'print UUID'
    def generate_uuid
      puts SecureRandom.uuid
      0
    end

    desc 'version', 'print version'
    def version
      puts CFnDK::VERSION
      0
    end

    desc 'init', 'craete sample cfndk.yml & CloudFormation yaml & json files.'
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

    desc 'create', 'create keypair & stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml"
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
    option :properties, type: :hash, aliases: 'p', default: {}
    option :stack_names, type: :array
    option :keypair_names, type: :array
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

    desc 'destroy', 'destroy keypair & stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml"
    option :force, type: :boolean, aliases: 'f', default: false
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
    option :stack_names, type: :array
    option :keypair_names, type: :array
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

    desc 'report', 'report stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml"
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil
    option :stack_names, type: :array, aliases: 'n'
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

    desc 'keypair SUBCOMMAND ...ARGS', 'manage keypair'
    subcommand 'keypair', KeyPairCommand
    desc 'stack SUBCOMMAND ...ARGS', 'manage stack'
    subcommand 'stack', StackCommand

    private

    def load_config_data(options)
      raise "File does not exist. #{options[:config_path]}" unless File.file?(options[:config_path])
      data = open(options[:config_path], 'r') { |f| YAML.load(f) }
      return data if data
      CFnDK.logger.error "File is empty. #{options[:config_path]}".color(:red)
      nil
    end
  end
end
