module CFnDK
  class KeyPair
    attr_reader :key_file, :enabled, :pre_command, :post_command
    def initialize(name, data, option, global_config, credentials)
      @global_config = global_config
      @name = name
      data = {} unless data
      @key_file = data['key_file'] || nil
      @region = data['region'] || @global_config.region
      @pre_command = data['pre_command'] || nil
      @post_command = data['post_command'] || nil
      @enabled = true
      @enabled = false if data['enabled'] === false
      @option = option
      @client = Aws::EC2::Client.new(credentials: credentials, region: @region)
      @dryrun = File.open(@option['dry_run'], 'a') if @option['dry_run']
    end

    def create
      return unless @enabled
      CFnDK.logger.info(('creating keypair: ' + name).color(:green))
      if @dryrun
        @dryrun.puts "aws ec2 create-key-pair --key-name #{name}"
      else
        key_pair = @client.create_key_pair(
          key_name: name
        )
        create_key_file(key_pair)
      end
      CFnDK.logger.info(('created keypair: ' + name).color(:green))
    end

    def destroy
      return unless @enabled
      if exists?
        CFnDK.logger.info(('deleting keypair: ' + name).color(:green))
        if @dryrun
          @dryrun.puts "aws ec2 delete-key-pair --key-name #{name}"
        else
          @client.delete_key_pair(
            key_name: name
          )
        end
        CFnDK.logger.info(('deleted keypair: ' + name).color(:green))
      else
        CFnDK.logger.info(('do not delete keypair: ' + name).color(:red))
      end
    end

    def exists?
      !@client.describe_key_pairs(
        key_names: [
          name,
        ]
      ).key_pairs.empty?
    rescue Aws::EC2::Errors::InvalidKeyPairNotFound
      false
    end

    def name
      [@name, @option[:uuid]].compact.join('-')
    end

    def original_name
      @name
    end

    def pre_command_execute
      return unless @enabled
      if @pre_command
        CFnDK.logger.info(('execute pre command: ' + @pre_command).color(:green))
        IO.popen(@pre_command, :err => [:child, :out]) do |io|
          io.each_line do |line|
            CFnDK.logger.info((line).color(:green))
          end
        end
        raise 'pre command is error. status: ' + $?.exitstatus.to_s + ' command: ' + @pre_command if $?.exitstatus != 0
      end
    end

    def post_command_execute
      return unless @enabled
      if @post_command
        CFnDK.logger.info(('execute post command: ' + @post_command).color(:green))
        IO.popen(@post_command, :err => [:child, :out]) do |io|
          io.each_line do |line|
            CFnDK.logger.info((line).color(:green))
          end
        end
        raise 'post command is error. status: ' + $?.exitstatus.to_s + ' command: ' + @post_command if $?.exitstatus != 0
      end
    end

    private

    def create_key_file(key_pair)
      return unless @key_file
      key_file = CFnDK::ErbString.new(@key_file, @option).value
      CFnDK.logger.info(('create key file: ' + key_file).color(:green))
      FileUtils.mkdir_p(File.dirname(key_file))
      File.write(key_file, key_pair.key_material)
    end
  end
end
