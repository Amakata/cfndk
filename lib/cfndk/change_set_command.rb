module CFnDK
  class ChangeSetCommand < Thor
    include SubcommandHelpReturnable
    include ConfigFileLoadable

    class_option :verbose, type: :boolean, aliases: 'v', desc: 'More verbose output.'
    class_option :color, type: :boolean, default: true, desc: 'Use colored output'
    class_option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    class_option :stack_names, type: :array, desc: 'Target stack names'

    desc 'create', 'Create change set'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :change_set_uuid, type: :string, default: ENV['CFNDK_CHANGE_SET_UUID'] || nil, desc: 'Use Change Set UUID'
    option :properties, type: :hash, aliases: 'p', default: {}, desc: 'Set property'
    def create
      CFnDK.logger.info 'create...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.validate
      stacks.create_change_set
      return 0
    rescue => e
      CFnDK.logger.error e.inspect.color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'execute', 'Execute change set'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :change_set_uuid, type: :string, default: ENV['CFNDK_CHANGE_SET_UUID'] || nil, desc: 'Use Change Set UUID'
    def execute
      CFnDK.logger.info 'execute...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.validate
      stacks.execute_change_set
      return 0
    rescue => e
      CFnDK.logger.error e.inspect.color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'destroy', 'Destroy change set'
    option :force, type: :boolean, aliases: 'f', default: false, desc: 'Say yes to all prompts for confirmation'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :change_set_uuid, type: :string, default: ENV['CFNDK_CHANGE_SET_UUID'] || nil, desc: 'Use Change Set UUID'
    def destroy
      CFnDK.logger.info 'destroy...'.color(:green)
      data = load_config_data(options)

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)

      if options[:force] || yes?('Are you sure you want to destroy? (y/n)', :yellow)
        stacks.delete_change_set
        return 0
      else
        CFnDK.logger.info 'destroy command was canceled'.color(:green)
        return 2
      end
    rescue => e
      CFnDK.logger.error e.inspect.color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'report', 'Report change set'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :change_set_uuid, type: :string, default: ENV['CFNDK_CHANGE_SET_UUID'] || nil, desc: 'Use Change Set UUID'
    option :types, type: :array, default: %w(tag parameter changes), desc: 'Report type'
    def report
      CFnDK.logger.info 'report...'.color(:green)
      data = load_config_data(options)
      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, options, credentials)
      stacks.report_change_set
      return 0
    rescue => e
      CFnDK.logger.error e.inspect.color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end
  end
end
