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
                  '    create                create stacks',
                  '    update                update stacks',
                  '    create-or-changeset   create stacks or create changeset',
                  '    destroy               destroy stacks',
                  '    generate-uuid         generate UUID',
                  '    report-event          report stack event',
                  '    report-stack          report stack',
                  '    report-stack-resource report stack resource',
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
      if ARGV.length != 1
        puts @opt.help
        return 2
      elsif ARGV[0] == 'generate-uuid'
        puts SecureRandom.uuid
        return 0
      elsif ARGV[0] == 'init'
        if File.file?(@option[:config_path])
          @logger.error "File exist. #{@option[:config_path]}".color(:red)
          return 1
        end
        @logger.info 'init...'.color(:green)
        FileUtils.cp_r(Dir.glob(File.dirname(__FILE__) + '/../../skel/*'), './')
        @logger.info "create #{@option[:config_path]}".color(:green)
        return 0
      end

      unless File.file?(@option[:config_path])
        @logger.error "File does not exist. #{@option[:config_path]}".color(:red)
        return 1
      end

      data = open(@option[:config_path], 'r') { |f| YAML.load(f) } if File.file?(@option[:config_path])
      credentials = CFnDK::CredentialProviderChain.new.resolve
      stacks = CFnDK::Stacks.new(data, @option, credentials)
      keypairs = CFnDK::KeyPairs.new(data, @option, credentials)

      if ARGV[0] == 'create'
        @logger.info 'create...'.color(:green)
        stacks.validate
        keypairs.create
        stacks.create
      elsif ARGV[0] == 'update'
        @logger.info 'update...'.color(:green)
        stacks.validate
        stacks.update
      elsif ARGV[0] == 'create-or-changeset'
        @logger.info 'create or changeset...'.color(:green)
        stacks.validate
        stacks.create_or_changeset
      elsif ARGV[0] == 'destroy'
        @logger.info 'destroy...'.color(:green)
        if destroy?
          stacks.destroy
          keypairs.destroy
        end
      elsif ARGV[0] == 'validate'
        @logger.info 'validate...'.color(:green)
        stacks.validate
      elsif ARGV[0] == 'report-event'
        @logger.info 'report event...'.color(:green)
        stacks.report_event
      elsif ARGV[0] == 'report-stack'
        @logger.info 'report stack...'.color(:green)
        stacks.report_stack
      elsif ARGV[0] == 'report-stack-resource'
        @logger.info 'report stack resource...'.color(:green)
        stacks.report_stack_resource
      else
        puts @opt.help
        return 2
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
