module CFnDK
  class Command
    def initialize
      @cur_dir = Dir.getwd
      @option = {
        config_path: "#{@cur_dir}/cfndk.yml",
        uuid: ENV['CFNDK_UUID'] || nil,
        properties: {},
        stack_names: nil,
        force: false,
      }

      @opt = OptionParser.new do |o|
        o.version = CFnDK::VERSION
        o.summary_indent = ' ' * 4
        o.banner = "Version: #{CFnDK::VERSION} \nUsage: cfndk [cmd] [options]"
        o.on_head('[cmd]',
                  '    init                  create config YAML file',
                  '    generate-uuid         generate UUID',
                  '*** KEY PAIR & STACK COMMANDS ***',
                  '    create',
                  '    destroy',
                  '    report',
                  '*** STACK COMMANDS ***',
                  '    stack create',
                  '    stack update',
                  '    stack destroy',
                  '    stack validate',
                  '    stack report',
                  '*** CHANGESET COMMANDS ***',
                  '    changeset create',
                  '    changeset destroy',
                  '    changeset report',
                  '*** KEYPAIR COMMANDS ***',
                  '    keypair create',
                  '    keypair destroy',
                  '[enviroment variables]',
                  "    AWS_PROFILE: #{ENV['AWS_PROFILE']}",
                  "    AWS_DEFAULT_REGION: #{ENV['AWS_DEFAULT_REGION']}",
                  "    AWS_REGION: #{ENV['AWS_REGION']}",
                  "    AWS_ACCESS_KEY_ID: #{ENV['AWS_ACCESS_KEY_ID']}",
                  "    AWS_SECRET_ACCESS_KEY: #{ENV['AWS_SECRET_ACCESS_KEY']}",
                  "    AWS_SESSION_TOKEN: #{ENV['AWS_SECRET_ACCESS_KEY']}",
                  "    AWS_CONTAINER_CREDENTIALS_RELATIVE_URI: #{ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI']}",
                  '[options]')
        o.on('-v', '--verbose', 'verbose mode') { |v| @option[:v] = v }
        o.on('-c', '--config_path cfndi.yml', "config path (default: #{@option[:config_path]})") { |v| @option[:config_path] = v }
        o.on('-p', '--properties name=value', 'properties') do |v|
          md = v.match(/^([a-zA-Z_]+[a-zA-Z0-9_]*)=(.*)$/)
          if md
            @option[:properties][md[0]] = md[1]
          else
            raise "invalid properties: '#{v}'" unless md
          end
        end
        o.on('-a', '--auto-uuid') { @option[:uuid] = SecureRandom.uuid }
        o.on('-u', '--uuid uuid') { |v| @option[:uuid] = v }
        o.on('-n', '--stack-names name1,name2') { |v| @option[:stack_names] = v.split(/\s*,\s*/) }
        o.on('--no-color') { |b| Rainbow.enabled = false }
        o.on('-f', '--force') { |b| @option[:force] = true }
        o.permute!(ARGV)
      end
      @logger = CFnDK::Logger.new(@option)
    end

    def execute
      code = execute_without_yaml
      code = execute_with_yaml if code.nil?
      return code if code
      puts @opt.help
      2
    end

    def execute_without_yaml
      case ARGV[0]
      when 'generate-uuid'
        puts SecureRandom.uuid
      when 'init'
        if File.file?(@option[:config_path])
          @logger.error "File exist. #{@option[:config_path]}".color(:red)
          return 1
        end
        @logger.info 'init...'.color(:green)
        FileUtils.cp_r(Dir.glob(File.dirname(__FILE__) + '/../../skel/*'), './')
        @logger.info "create #{@option[:config_path]}".color(:green)
      else
        return
      end
      0
    end

    def execute_with_yaml
      unless File.file?(@option[:config_path])
        @logger.error "File does not exist. #{@option[:config_path]}".color(:red)
        return 1
      end
      data = open(@option[:config_path], 'r') { |f| YAML.load(f) }

      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, @option, credentials)
      keypairs = CFnDK::KeyPairs.new(data, @option, credentials)

      case ARGV[0]
      when 'create'
        @logger.info 'create...'.color(:green)
        stacks.validate
        keypairs.create
        stacks.create
      when 'destroy'
        @logger.info 'destroy...'.color(:green)
        if destroy?
          stacks.destroy
          keypairs.destroy
        end
      when 'report'
        @logger.info 'report...'.color(:green)
        stacks.report
      when 'stack'
        execute_stack(stacks)
      when 'changeset'
        execute_changeset(stacks)
      when 'keypair'
        execute_keypair(keypairs)
      else
        return
      end
      0
    end

    def execute_stack(stacks)
      case ARGV[1]
      when 'craete'
        @logger.info 'create...'.color(:green)
        stacks.validate
        stacks.create
      when 'update'
        @logger.info 'update...'.color(:green)
        stacks.validate
        stacks.update
      when 'destroy'
        @logger.info 'destroy...'.color(:green)
        stacks.destroy if destroy?
      when 'validate'
        @logger.info 'validate...'.color(:green)
        stacks.validate
      when 'report'
        @logger.info 'report...'.color(:green)
        stacks.report
      else
        return
      end
      0
    end

    def execute_changeset(stacks)
      case ARGV[1]
      when 'create'
        @logger.info 'create...'.color(:green)
        stacks.create_change_set
      when 'destroy'
        @logger.info 'destroy...'.color(:green)
        stacks.destroy_change_set
      when 'report'
        stacks.report_change_set
      else
        return
      end
      0
    end

    def execute_keypair(keypairs)
      case ARGV[1]
      when 'create'
        @logger.info 'create...'.color(:green)
        keypairs.create
      when 'destroy'
        @logger.info 'destroy...'.color(:green)
        keypairs.destroy if destroy?
      else
        return
      end
      0
    end

    def destroy?
      return true if @option[:force]
      loop do
        print 'destroy? [yes|no]:'
        res = STDIN.gets
        case res
        when /^yes/
          return true
        when /^no/, /^$/
          return false
        end
      end
    end
  end
end
