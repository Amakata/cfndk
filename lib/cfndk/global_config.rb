module CFnDK
  class GlobalConfig
    attr_reader :timeout_in_minutes, :s3_template_bucket, :s3_template_hash, :region, :role_arn, :package, :profile
    def initialize(data, option)
      @timeout_in_minutes = 1
      @s3_template_bucket = 'cfndk-templates'
      @s3_template_hash = Uuid.instance.uuid
      @region = ENV['AWS_REGION'] || 'us-east-1'
      @package = false
      @profile = ENV['AWS_PROFILE'] || nil
      return unless data['global'].is_a?(Hash)
      @timeout_in_minutes = data['global']['timeout_in_minutes'] || 1
      @s3_template_bucket = data['global']['s3_template_bucket'] || 'cfndk-templates'
      @region = data['global']['region'] || ENV['AWS_REGION'] || 'us-east-1'
      @package = data['global']['package'] === 'true' ? true : false
      @role_arn = data['global']['role_arn'] || nil
      @profile = ENV['AWS_PROFILE'] || data['global']['profile'] || nil
    end
  end
end
