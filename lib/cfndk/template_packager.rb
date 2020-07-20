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
      @is_uploaded = false
    end

    def large_template?
      template_body.size > 51200
    end

    def template_body
      package_templte
    end

    def upload_template_file
      key = [@global_config.s3_template_hash, @template_file].compact.join('/')
      url = "https://s3.amazonaws.com/#{bucket_name}/#{key}"

      unless @is_uploaded
        create_bucket
        @s3_client.put_object(
          body: template_body,
          bucket: bucket_name,
          key: key
        )
        @is_uploaded = true
        CFnDK.logger.info('Put S3 object: ' + url + ' Size: ' + template_body.size.to_s)
      end
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
                result = upload_zip_file(File.dirname(@template_file) + '/' + properties['Code'].sub(/^\s*.\//, ''))
                v['Properties']['Code'] = {
                  'S3Bucket' => result['bucket'],
                  'S3Key' => result['key']  
                }
              end
            when 'AWS::Serverless::Function' then
              if properties['CodeUri'].kind_of?(String)
                result = upload_zip_file(File.dirname(@template_file) + '/' + properties['CodeUri'].sub(/^\s*.\//, ''))
                v['Properties']['CodeUri'] = {
                  'Bucket' => result['bucket'],
                  'Key' => result['key']  
                }
              end
            when 'AWS::Serverless::Api' then
              if properties['DefinitionUri'].kind_of?(String)
                result = upload_file(File.dirname(@template_file) + '/' + properties['DefinitionUri'].sub(/^\s*.\//, ''))
                v['Properties']['DefinitionUri'] = {
                  'Bucket' => result['bucket'],
                  'Key' => result['key']  
                }
              end
            when 'AWS::ApiGateway::RestApi' then
              if properties['BodyS3Location'].kind_of?(String)
                result = upload_file(File.dirname(@template_file) + '/' + properties['BodyS3Location'].sub(/^\s*.\//, ''))
                v['Properties']['BodyS3Location'] = {
                  'Bucket' => result['bucket'],
                  'Key' => result['key']  
                }
              end
            end
            ## TODO support resources
            # * AWS::AppSync::GraphQLSchema DefinitionS3Location
            # * AWS::AppSync::Resolver RequestMappingTemplateS3Location
            # * AWS::AppSync::Resolver ResponseMappingTemplateS3Location
            # * AWS::ElasticBeanstalk::ApplicationVersion SourceBundle
            # * AWS::Glue::Job Command ScriptLocation
            # * AWS::Include Location
          end
        end

        if is_json?(orgTemplate)
          @template_body = JSON.dump(data)
        else
          @template_body = YAML.dump_stream(data).gsub(/____CFNDK!____/, '!')
        end
        CFnDK.logger.info('Template Packager diff: ' + @template_file) 
        CFnDK.logger.info(CFnDK.diff(orgTemplate, @template_body).to_s)
        CFnDK.logger.debug('Package Template size: ' + @template_body.size.to_s)
        CFnDK.logger.debug('Package Template:' + @template_body)
      end
      @template_body
    end

    private

    def upload_zip_file(path)
      create_bucket
      key = [@global_config.s3_template_hash, path.sub(/^.\//, '') + ".zip"].compact.join('/')


      buffer = Zip::OutputStream.write_buffer do |out|
        Dir.glob(path + '/**/*') do |file|
          if (!File.directory?(file))
            out.put_next_entry(file.delete_prefix(path + '/'))
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
        'bucket' => bucket_name,
        'key' => key
      }
    end

    def upload_file(path)
      create_bucket
      key = [@global_config.s3_template_hash, path.sub(/^.\//, '')].compact.join('/')

      @s3_client.put_object(
        body: File.open(path, 'r').read,
        bucket: bucket_name,
        key: key
      )
      url = "https://s3.amazonaws.com/#{bucket_name}/#{key}"
      CFnDK.logger.info('Put S3 object: ' + url)
      {
        'bucket' => bucket_name,
        'key' => key
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