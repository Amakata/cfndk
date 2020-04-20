module CFnDK
  class Command < Thor
    include Thor::Actions
    include ConfigFileLoadable
    include CredentialResolvable

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
      credentials = resolve_credential(data, options)

      stacks = CFnDK::Stacks.new(data, options, credentials)
      keypairs = CFnDK::KeyPairs.new(data, options, credentials)

      stacks.pre_command_execute
      stacks.validate
      keypairs.create
      stacks.create
      stacks.post_command_execute
      return 0
    rescue => e
      CFnDK.logger.error "#{e.class}: #{e.message}".color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'destroy', 'Destroy keypair & stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    option :force, type: :boolean, aliases: 'f', default: false, desc: 'Say yes to all prompts for confirmation'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    def destroy
      CFnDK.logger.info 'destroy...'.color(:green)
      data = load_config_data(options)
      credentials = resolve_credential(data, options)

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
      CFnDK.logger.error "#{e.class}: #{e.message}".color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'report', 'Report stack'
    option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :stack_names, type: :array, desc: 'Target stack names'
    option :types, type: :array, default: %w(tag output parameter resource event), desc: 'Report type'
    def report
      CFnDK.logger.info 'report...'.color(:green)

      data = load_config_data(options)
      credentials = resolve_credential(data, options)

      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.report
      return 0
    rescue => e
      CFnDK.logger.error "#{e.class}: #{e.message}".color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
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
    desc 'changeset SUBCOMMAND ...ARGS', 'Manage change set'
    subcommand 'changeset', ChangeSetCommand
  end
end
