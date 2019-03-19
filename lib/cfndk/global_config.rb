module CFnDK
  class GlobalConfig
    attr_reader :timeout_in_minutes, :s3_template_bucket, :s3_template_hash, :region
    def initialize(data, option)
      @timeout_in_minutes = 1
      @s3_template_bucket = 'cfndk-templates'
      @s3_template_hash = SecureRandom.uuid
      @region = ENV['AWS_REGION'] || 'us-east-1'
      return unless data['global'].is_a?(Hash)
      @timeout_in_minutes = data['global']['timeout_in_minutes'] || 1
      @s3_template_bucket = data['global']['s3_template_bucket'] || 'cfndk-templates'
      @region = data['global']['region'] || ENV['AWS_REGION'] || 'us-east-1'
    end
  end
end
