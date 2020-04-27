module CFnDK
  class GlobalConfig
    attr_reader :timeout_in_minutes, :s3_template_bucket, :s3_template_hash, :region, :role_arn, :package, :profile, :pre_command, :post_command
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
      @profile = ENV['AWS_PROFILE'] || data['global']['default_profile'] || nil
      @pre_command = data['global']['pre_command'] || nil
      @post_command = data['global']['post_command'] || nil
    end

    def pre_command_execute
      if @pre_command
        CFnDK.logger.info(('execute global pre command: ' + @pre_command).color(:green))
        IO.popen(@pre_command, :err => [:child, :out]) do |io|
          io.each_line do |line|
            CFnDK.logger.info((line).color(:green))
          end
        end
        raise 'global pre command is error. status: ' + $?.exitstatus.to_s + ' command: ' + @pre_command if $?.exitstatus != 0
      end
    end

    def post_command_execute
      if @post_command
        CFnDK.logger.info(('execute global post command: ' + @post_command).color(:green))
        IO.popen(@post_command, :err => [:child, :out]) do |io|
          io.each_line do |line|
            CFnDK.logger.info((line).color(:green))
          end
        end
        raise 'global post command is error. status: ' + $?.exitstatus.to_s + ' command: ' + @post_command if $?.exitstatus != 0
      end
    end
  end
end
