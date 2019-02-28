module CFnDK
  class KeyPair
    attr_reader :key_file
    def initialize(name, data, option, credentials)
      @name = name
      @key_file = nil
      @key_file = data['key_file'] || nil if data
      @option = option
      @client = Aws::EC2::Client.new(credentials: credentials)
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
      CFnDK.logger.info(('deleting keypair: ' + name).color(:green))
      @client.delete_key_pair(
        key_name: name
      )
      CFnDK.logger.info(('deleted keypair: ' + name).color(:green))
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
      File.write(key_file, key_pair.key_material)
    end
  end
end
