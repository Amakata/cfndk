module CFnDK
  class TemplatePackager
    def initialize(template_file, region, package, global_config, s3_client, sts_client)
      @template_file = template_file
      @region = region
      @package = package
      @global_config = global_config
      @s3_client = s3_client
      @sts_client = sts_client
      @template_body = nil
    end

    def large_template?
      template_body.size > 51200
    end

    def template_body
      package_templte
    end

    def upload_template_file
      create_bucket

      key = [@global_config.s3_template_hash, @template_file].compact.join('/')
      @s3_client.put_object(
        body: template_body,
        bucket: bucket_name,
        key: key
      )
      url = "https://s3.amazonaws.com/#{bucket_name}/#{key}"
      CFnDK.logger.info('Put S3 object: ' + url)
      url
    end

    def package_templte
      if !@template_body
        if !@package
          @template_body = File.open(@template_file, 'r').read
          return @template_body
        end
        orgTemplate = File.open(@template_file, 'r').read
        CFnDK.logger.debug('Original Template:' + orgTemplate)
        if is_json?(orgTemplate)
          data = JSON.parse(orgTemplate)
        else
          data = YAML.load(orgTemplate.gsub(/!/, '____CFNDK!____'))
        end
        
        if data['Resources']
          data['Resources'].each do |k, v|
            next unless v.key?('Type')
            t = v['Type'] 
            properties = v['Properties'] || {}
            case t
            when 'AWS::CloudFormation::Stack' then
              if properties['TemplateURL'] =~ /^\s*./
                tp = TemplatePackager.new(File.dirname(@template_file) + '/' + properties['TemplateURL'].sub(/^\s*.\//, ''), @region, @package, @global_config, @s3_client, @sts_client)
                v['Properties']['TemplateURL'] = tp.upload_template_file
              end
            when 'AWS::Lambda::Function' then
              if properties['Code'].kind_of?(String)
                v['Properties']['Code'] = upload_zip_file(File.dirname(@template_file) + '/' + properties['Code'].sub(/^\s*.\//, ''))
              end
            end
          end
        end

        if is_json?(orgTemplate)
          @template_body = JSON.dump(data)
        else
          @template_body = YAML.dump_stream(data).gsub(/____CFNDK!____/, '!')
        end
        CFnDK.logger.debug('Package Template size:' + @template_body.size.to_s)
        CFnDK.logger.debug('Package Template:' + @template_body)
      end
      @template_body
    end
    
=begin
            when 'AWS::ApiGateway::RestApi' then
            when 'AWS::Serverless::Function' then
            when 'AWS::AppSync::GraphQLSchema' then
            when 'AWS::AppSync::Resolver' then
            when 'AWS::Serverless::Api' then
            when 'AWS::Include' then
            when 'AWS::ElasticBeanstalk::ApplicationVersion' then
            when 'AWS::Glue::Job' then
=end
=begin
          when 'AWS::ApiGateway::RestApi' then
            if v['Properties'] && v['Properties']['BodyS3Location'] =~ /^\s*./
              files[k] = { type: v['Type'], path: v['Properties']['BodyS3Location'] }
            end
          when 'AWS::Serverless::Function' then
            if v['Properties'] && v['Properties']['CodeUri'] =~ /^\s*./
              files[k] = { type: v['Type'], path: v['Properties']['CodeUri'] }
            end
          when 'AWS::AppSync::GraphQLSchema' then
            if v['Properties'] && v['Properties']['DefinitionS3Location'] =~ /^\s*./
              files[k] = { type: v['Type'], path: v['Properties']['DefinitionS3Location'] }
            end
          when 'AWS::AppSync::Resolver' then
            if v['Properties'] && v['Properties']['RequestMappingTemplateS3Location'] =~ /^\s*./
              files[k] = { type: v['Type'] + '::RequestMappingTemplateS3Location', path: v['Properties']['RequestMappingTemplateS3Location'] }
            end
            if v['Properties'] && v['Properties']['ResponseMappingTemplateS3Location'] =~ /^\s*./
              files[k] = { type: v['Type'] + '::ResponseMappingTemplateS3Location', path: v['Properties']['ResponseMappingTemplateS3Location'] }
            end
          when 'AWS::Serverless::Api' then
            if v['Properties'] && v['Properties']['DefinitionUri'] =~ /^\s*./
              files[k] = { type: v['Type'], path: v['Properties']['DefinitionUri'] }
            end
          when 'AWS::Include' then
            if v['Properties'] && v['Properties']['Location'] =~ /^\s*./
              files[k] = { type: v['Type'], path: v['Properties']['Location'] }
            end
          when 'AWS::ElasticBeanstalk::ApplicationVersion' then
            if v['Properties'] && v['Properties']['SourceBundle'] =~ /^\s*./
              files[k] = { type: v['Type'], path: v['Properties']['SourceBundle'] }
            end
          when 'AWS::Glue::Job' then
            if v['Properties'] && v['Properties']['Command'] && v['Properties']['Command']['ScriptLocation'] =~ /^\s*./
              files[k] = { type: v['Type'], path: v['Properties']['Command']['ScriptLocation'] }
            end
          end
=end

    private

    def upload_zip_file(path)
      create_bucket
      key = [@global_config.s3_template_hash, path + ".zip"].compact.join('/')


      buffer = Zip::OutputStream.write_buffer do |out|
        Dir.glob(path + '/**/*') do |file|
          if (!File.directory?(file))
            out.put_next_entry(file)
            out.write(File.open(file, 'r').read)
          end
        end
      end

      @s3_client.put_object(
        body: buffer.string,
        bucket: bucket_name,
        key: key
      )
      url = "https://s3.amazonaws.com/#{bucket_name}/#{key}"
      CFnDK.logger.info('Put S3 object: ' + url)
      {
        'S3Bucket' => bucket_name,
        'S3Key' => key
      }
    end

    def create_bucket
      begin
        @s3_client.head_bucket(bucket: bucket_name)
      rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::Forbidden
        @s3_client.create_bucket(bucket: bucket_name)
        CFnDK.logger.info('Creatt S3 bucket: ' + bucket_name)
        @s3_client.put_bucket_lifecycle_configuration(
          bucket: bucket_name,
          lifecycle_configuration: {
            rules: [
              {
                expiration: {
                  days: 1,
                },
                status: 'Enabled',
                id: 'Delete Old Files',
                prefix: '',
                abort_incomplete_multipart_upload: {
                  days_after_initiation: 1,
                },
              },
            ],
          }
        )
      end      
    end

    def bucket_name
      resp = @sts_client.get_caller_identity({})
      resp.account + '-' + @region + '-' + @global_config.s3_template_bucket
    end

    def is_json?(str)
      begin
        !!JSON.parse(str)
      rescue
        false
      end
    end
  end
end