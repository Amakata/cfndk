module CFnDK
  class Stack
    attr_reader :template_file, :parameter_input, :capabilities, :depends, :timeout_in_minutes
    def initialize(name, data, option)
      @name = name
      @template_file = data['template_file'] || ''
      @parameter_input = data['parameter_input'] || ''
      @capabilities = data['capabilities'] || []
      @depends = data['depends'] || []
      @timeout_in_minutes = data['timeout_in_minutes'] || 1
      @override_parameters = data['parameters'] || {}
      @option = option
    end

    def name
      [@name, @option[:uuid]].compact.join('-')
    end

    def template_body
      File.open(@template_file, 'r').read
    end

    def parameters
      json = JSON.load(open(@parameter_input).read)
      json['Parameters'].map do |item|
        next if item.empty?
        {
          parameter_key: item['ParameterKey'],
          parameter_value: eval_override_parameter(item['ParameterKey'], item['ParameterValue']),
        }
      end.compact
    end

    private

    def eval_override_parameter(k, v)
      if @override_parameters[k]
        CFnDK::ErbString.new(@override_parameters[k], @option).value
      else
        v
      end
    end
  end
end
