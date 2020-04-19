module CFnDK
  class Uuid
    include Singleton
    
    attr_reader :uuid
    def initialize()
      @uuid = SecureRandom.uuid
    end
  end
end
