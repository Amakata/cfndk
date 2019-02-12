module CFnDK
  class ParameterString
    attr_reader :uuid, :properties
    def initialize(str, option)
      @erb = ERB.new(str, nil, '-')
      @properties = option[:properties]
      @uuid = option[:uuid]
    end

    def value
      @erb.result(binding)
    end

    def append_uuid(glue = '-')
      if uuid
        glue + uuid
      else
        ''
      end
    end
  end
end
