module CFnDK
  class KeyPairCommand < Thor
    include SubcommandHelpReturnable
    include ConfigFileLoadable
    include CredentialResolvable

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
      credentials = resolve_credential(data, options)

      keypairs = CFnDK::KeyPairs.new(data, options, credentials)
      keypairs.create
      return 0
    rescue => e
      CFnDK.logger.error "#{e.class}: #{e.message}".color(:red)
      e.backtrace_locations.each do |line|
        CFnDK.logger.debug line
      end
      return 1
    end

    desc 'destroy', 'Destroy keypair'
    option :force, type: :boolean, aliases: 'f', default: false, desc: 'Say yes to all prompts for confirmation'
    def destroy
      CFnDK.logger.info 'destroy...'.color(:green)
      data = load_config_data(options)
      credentials = resolve_credential(data, options)

      keypairs = CFnDK::KeyPairs.new(data, options, credentials)

      if options[:force] || yes?('Are you sure you want to destroy? (y/n)', :yellow)
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
  end
end
