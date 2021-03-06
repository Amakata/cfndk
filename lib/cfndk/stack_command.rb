module CFnDK
  class StackCommand < Thor
    include SubcommandHelpReturnable
    include ConfigFileLoadable
    include CredentialResolvable

    class_option :verbose, type: :boolean, aliases: 'v', desc: 'More verbose output.'
    class_option :color, type: :boolean, default: true, desc: 'Use colored output'
    class_option :config_path, type: :string, aliases: 'c', default: "#{Dir.getwd}/cfndk.yml", desc: 'The configuration file to use'
    class_option :stack_names, type: :array, aliases: 's', desc: 'Target stack names'

    desc 'create', 'Create stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :properties, type: :hash, aliases: 'p', default: {}, desc: 'Set property'
    def create
      CFnDK.logger.info 'create...'.color(:green)
      data = load_config_data(options)
      credentials = resolve_credential(data, options)
      global_config = CFnDK::GlobalConfig.new(data, options)
      stacks = CFnDK::Stacks.new(data, options, credentials)
      
      global_config.pre_command_execute
      stacks.pre_command_execute
      stacks.validate
      stacks.create
      stacks.post_command_execute
      global_config.post_command_execute
      return 0
    rescue => e
      CFnDK.logger.error "#{e.class}: #{e.message}".color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'update', 'Update stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    option :properties, type: :hash, aliases: 'p', default: {}, desc: 'Set property'
    def update
      CFnDK.logger.info 'update...'.color(:green)
      data = load_config_data(options)
      credentials = resolve_credential(data, options)
      global_config = CFnDK::GlobalConfig.new(data, options)
      stacks = CFnDK::Stacks.new(data, options, credentials)

      global_config.pre_command_execute
      stacks.pre_command_execute
      stacks.validate
      stacks.update
      stacks.post_command_execute
      global_config.post_command_execute
      return 0
    rescue => e
      CFnDK.logger.error "#{e.class}: #{e.message}".color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'destroy', 'Destroy stack'
    option :force, type: :boolean, aliases: 'f', default: false, desc: 'Say yes to all prompts for confirmation'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
    def destroy
      CFnDK.logger.info 'destroy...'.color(:green)
      data = load_config_data(options)
      credentials = resolve_credential(data, options)

      stacks = CFnDK::Stacks.new(data, options, credentials)

      if options[:force] || yes?('Are you sure you want to destroy? (y/n)', :yellow)
        stacks.destroy
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

    desc 'validate', 'Validate stack'
    def validate
      CFnDK.logger.info 'validate...'.color(:green)
      data = load_config_data(options)
      credentials = resolve_credential(data, options)
      global_config = CFnDK::GlobalConfig.new(data, options)
      stacks = CFnDK::Stacks.new(data, options, credentials)

      global_config.pre_command_execute
      stacks.pre_command_execute
      stacks.validate
      stacks.post_command_execute
      global_config.post_command_execute
      return 0
    rescue => e
      CFnDK.logger.error "#{e.class}: #{e.message}".color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'report', 'Report stack'
    option :uuid, type: :string, aliases: 'u', default: ENV['CFNDK_UUID'] || nil, desc: 'Use UUID'
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
  end
end
