module CFnDK
  module ConfigFileLoadable
    private

    def load_config_data(options)
      raise "File does not exist. #{options[:config_path]}" unless File.file?(options[:config_path])
      data = open(options[:config_path], 'r') { |f| YAML.load(f) }
      return data if data
      CFnDK.logger.error "File is empty. #{options[:config_path]}".color(:red)
      nil
    end
  end
end