module CFnDK
  class KeyPair
    attr_reader :key_file
    def initialize(name, data, option, global_config, credentials)
      @global_config = global_config
      @name = name
      @key_file = nil
      @key_file = data['key_file'] || nil if data
      @option = option
      @client = Aws::EC2::Client.new(credentials: credentials, region: @global_config.region)
    end

    def create
      CFnDK.logger.info(('creating keypair: ' + name).color(:green))
      key_pair = @client.create_key_pair(
        key_name: name
      )
      CFnDK.logger.info(('created keypair: ' + name).color(:green))

      create_key_file(key_pair)
    end

    def destroy
      if exists?
        CFnDK.logger.info(('deleting keypair: ' + name).color(:green))
        @client.delete_key_pair(
          key_name: name
        )
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
