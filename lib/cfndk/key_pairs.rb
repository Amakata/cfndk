module CFnDK
  class KeyPairs
    def initialize(data, option, credentials)
      @option = option
      @credentials = credentials
      prepare_keypairs(data)
    end

    def create
      return if @option[:keypair_names].instance_of?(Array)
      @keypairs.each_value(&:create)
    end

    def destroy
      return if @option[:keypair_names].instance_of?(Array)
      @keypairs.each_value(&:destroy)
    end

    private

    def prepare_keypairs(data)
      @keypairs = {}
      return unless data['keypairs']
      data['keypairs'].each do |name, properties|
        @keypairs[name] = KeyPair.new(name, properties, @option, @credentials)
      end
    end
  end
end
