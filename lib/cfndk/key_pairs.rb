module CFnDK
  class KeyPairs
    def initialize(data, option, credentials)
      @option = option
      @credentials = credentials
      @global_config = CFnDK::GlobalConfig.new(data, option)
      prepare_keypairs(data)
    end

    def create
      @keypairs.each_value do |keypair|
        next if @option[:keypair_names].instance_of?(Array) && !@option[:keypair_names].include?(keypair.original_name)
        keypair.create
      end
    end

    def destroy
      @keypairs.each_value do |keypair|
        next if @option[:keypair_names].instance_of?(Array) && !@option[:keypair_names].include?(keypair.original_name)
        keypair.destroy
      end
    end

    def pre_command_execute
      @keypairs.each_value do |keypair|
        keypair.pre_command_execute
      end
    end

    def post_command_execute
      @keypairs.each_value do |keypair|
        keypair.post_command_execute
      end
    end

    private

    def prepare_keypairs(data)
      @keypairs = {}
      return unless data['keypairs']
      data['keypairs'].each do |name, properties|
        @keypairs[name] = KeyPair.new(name, properties, @option, @global_config, @credentials)
      end
    end
  end
end
