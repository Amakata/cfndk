module CFnDK
  class Stack
    attr_reader :template_file, :parameter_input, :capabilities, :depends, :timeout_in_minutes, :region
    def initialize(name, data, option, global_config, credentials)
      @global_config = global_config
      @name = name
      @template_file = data['template_file'] || ''
      @parameter_input = data['parameter_input'] || ''
      @capabilities = data['capabilities'] || []
      @depends = data['depends'] || []
      @region = data['region'] || @global_config.region
      @timeout_in_minutes = data['timeout_in_minutes'] || @global_config.timeout_in_minutes
      @override_parameters = data['parameters'] || {}
      @option = option
      @client = Aws::CloudFormation::Client.new(credentials: credentials, region: @region)
      @s3_client = Aws::S3::Client.new(credentials: credentials, region: @region)
    end

    def create
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('creating stack: ' + name).color(:green))
      CFnDK.logger.debug('Name        :' + name)
      CFnDK.logger.debug('Parametres  :' + parameters.inspect)
      CFnDK.logger.debug('Capabilities:' + capabilities.inspect)
      CFnDK.logger.debug('Timeout     :' + timeout_in_minutes.to_s)
      CFnDK.logger.debug('Region      :' + region)
      tags = [
        {
          key: 'origina_name',
          value: @name,
        },
      ]
      tags.push(
        key: 'UUID',
        value: @option[:uuid]
      ) if @option[:uuid]
      hash = {
        stack_name: name,
        parameters: parameters,
        capabilities: capabilities,
        timeout_in_minutes: timeout_in_minutes,
        tags: tags,
      }
      if large_template?
        hash[:template_url] = upload_template_file()
      else
        hash[:template_body] = template_body()
      end
      @client.create_stack(
        hash
      )
    end

    def wait_until_create
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('waiting create stack: ' + name).color(:green))
      begin
        @client.wait_until(
          :stack_create_complete,
          stack_name: name
        ) do |w|
          w.max_attempts = 360
          w.delay = 10
        end
        CFnDK.logger.info(('created stack: ' + name).color(:green))
      rescue Aws::Waiters::Errors::FailureStateError => ex
        CFnDK.logger.error "#{ex.class}: #{ex.message}".color(:red)
        @option[:type] = %w(tag output parameter resource event)
        report
        raise ex
      end
    end

    def update
      return false if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('updating stack: ' + name).color(:green))
      CFnDK.logger.debug('Name        :' + name)
      CFnDK.logger.debug('Parametres  :' + parameters.inspect)
      CFnDK.logger.debug('Capabilities:' + capabilities.inspect)
      CFnDK.logger.debug('Timeout     :' + timeout_in_minutes.to_s)
      CFnDK.logger.debug('Region      :' + region)
      begin
        hash = {
          stack_name: name,
          parameters: parameters,
          capabilities: capabilities,
        }
        if large_template?
          hash[:template_url] = upload_template_file()
        else
          hash[:template_body] = template_body()
        end
        @client.update_stack(
          hash
        )
        true
      rescue Aws::CloudFormation::Errors::ValidationError => ex
        case ex.message
        when 'No updates are to be performed.'
          CFnDK.logger.warn "#{ex.message}: #{name}".color(:red)
          false
        else
          raise ex
        end
      end
    end

    def wait_until_update
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('waiting update stack: ' + name).color(:green))
      @client.wait_until(
        :stack_update_complete,
        stack_name: name
      ) do |w|
        w.max_attempts = 360
        w.delay = 10
      end
      CFnDK.logger.info(('updated stack: ' + name).color(:green))
    end

    def destroy
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      if exits?
        CFnDK.logger.info(('deleting stack: ' + name).color(:green))
        CFnDK.logger.debug('Name        :' + name)
        CFnDK.logger.debug('Region      :' + region)
        @client.delete_stack(
          stack_name: name
        )
      else
        CFnDK.logger.info(('do not delete stack: ' + name).color(:red))
      end
    end

    def wait_until_destroy
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      return unless exits?
      CFnDK.logger.info(('waiting delete stack: ' + name).color(:green))
      @client.wait_until(
        :stack_delete_complete,
        stack_name: name
      ) do |w|
        w.max_attempts = 360
        w.delay = 10
      end
      CFnDK.logger.info(('deleted stack: ' + name).color(:green))
    end

    def create_change_set
      return nil if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('creating change set: ' + change_set_name).color(:green))
      CFnDK.logger.debug('Parametres  :' + parameters.inspect)
      CFnDK.logger.debug('Capabilities:' + capabilities.inspect)
      CFnDK.logger.debug('Region      :' + region)
      tags = [
        {
          key: 'origina_name',
          value: @name,
        },
      ]
      tags.push(
        key: 'UUID',
        value: @option[:uuid]
      ) if @option[:uuid]
      tags.push(
        key: 'CHANGE_SET_UUID',
        value: @option[:change_set_uuid]
      ) if @option[:change_set_uuid]
      hash = {
        stack_name: name,
        parameters: parameters,
        capabilities: capabilities,
        change_set_name: change_set_name,
        change_set_type: exits? ? 'UPDATE' : 'CREATE',
        tags: tags,
      }
      if large_template?
        hash[:template_url] = upload_template_file()
      else
        hash[:template_body] = template_body()
      end
      @client.create_change_set(
        hash
      )
      @name
    rescue Aws::CloudFormation::Errors::ValidationError => ex
      if review_in_progress?
        CFnDK.logger.warn("failed create change set because the stack on REVIEW_IN_PROGRESS already exist : #{change_set_name}".color(:orange))
        nil
      else
        CFnDK.logger.error("failed create change set: #{change_set_name}".color(:red))
        raise ex
      end
    end

    def wait_until_create_change_set
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      return unless exits?
      CFnDK.logger.info(('waiting create change set: ' + change_set_name).color(:green))
      @client.wait_until(
        :change_set_create_complete,
        stack_name: name,
        change_set_name: change_set_name
      ) do |w|
        w.max_attempts = 360
        w.delay = 10
      end
      CFnDK.logger.info("created change set: #{change_set_name}".color(:green))
    rescue Aws::Waiters::Errors::FailureStateError => ex
      case ex.message
      when 'stopped waiting, encountered a failure state'
        unless available_change_set?
          delete_change_set
          CFnDK.logger.warn("failed create change set because this change set is UNAVAILABLE: #{change_set_name}".color(:orange))
          return
        end
      end
      raise ex
    end

    def execute_change_set
      return nil if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      if available_change_set?
        CFnDK.logger.info(('executing change set: ' + change_set_name).color(:green))
        @client.execute_change_set(
          stack_name: name,
          change_set_name: change_set_name
        )
        CFnDK.logger.info(('execute change set: ' + change_set_name).color(:green))
        @name
      else
        CFnDK.logger.warn("failed execute change set because this change set is not AVAILABLE: #{change_set_name}".color(:orange))
        nil
      end
    end

    def delete_change_set
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('deleting change set: ' + change_set_name).color(:green))
      @client.delete_change_set(
        stack_name: name,
        change_set_name: change_set_name
      )
      CFnDK.logger.info(('deleted change set: ' + change_set_name).color(:green))
    end

    def report_change_set
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info('*****************************************************'.color(:green))
      CFnDK.logger.info(('change set: ' + change_set_name).color(:green))
      CFnDK.logger.info('*****************************************************'.color(:green))
      CFnDK.logger.info('')
      resp = @client.describe_change_set(
        change_set_name: change_set_name,
        stack_name: name
      )
      CFnDK.logger.info('Execution Status: '.color(:green) + colored_status(resp.execution_status))
      CFnDK.logger.info('Status:           '.color(:green) + colored_status(resp.status))
      CFnDK.logger.info('Reason:           '.color(:green) + resp.status_reason) if resp.status_reason
      if @option[:types].instance_of?(Array) && @option[:types].include?('tag')
        CFnDK.logger.info('Tags:'.color(:green))
        tags_rows = resp.tags.map do |item|
          [
            item.key,
            item.value,
          ]
        end
        unless tags_rows.empty?
          table = Terminal::Table.new headings: %w(Key Value), rows: tags_rows
          CFnDK.logger.info table
        end
      end
      if @option[:types].instance_of?(Array) && @option[:types].include?('parameter')
        CFnDK.logger.info('Parameters:'.color(:green))
        parameter_rows = resp.parameters.map do |item|
          [
            item.parameter_key,
            item.parameter_value,
            item.use_previous_value,
            item.resolved_value,
          ]
        end
        unless parameter_rows.empty?
          table = Terminal::Table.new headings: ['Key', 'Value', 'Use Previous Value', 'Resolved Value'], rows: parameter_rows
          CFnDK.logger.info table
        end
      end
      if @option[:types].instance_of?(Array) && @option[:types].include?('changes')
        CFnDK.logger.info('Changes:'.color(:green))
        changes_rows = resp.changes.map do |item|
          [
            item.resource_change.action,
            item.resource_change.logical_resource_id,
            item.resource_change.physical_resource_id,
            item.resource_change.resource_type,
            item.resource_change.replacement,
          ]
        end
        unless changes_rows.empty?
          table = Terminal::Table.new headings: %w(Action Logical Physical Type Replacement), rows: changes_rows
          CFnDK.logger.info table
        end
      end
    rescue Aws::CloudFormation::Errors::ValidationError => ex
      CFnDK.logger.warn "#{ex.class}: #{ex.message}".color(:red)
    rescue Aws::CloudFormation::Errors::ChangeSetNotFound => ex
      CFnDK.logger.warn "#{ex.class}: #{ex.message}".color(:red)
    end

    def validate
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('validate stack: ' + name).color(:green))
      CFnDK.logger.debug('Name        :' + @name)
      @client.validate_template(
        template_body: template_body
      )
    end

    def exits?
      @client.describe_stacks(
        stack_name: name
      )
      true
    rescue Aws::CloudFormation::Errors::ValidationError
      false
    end

    def created?
      resp = @client.describe_stacks(
        stack_name: name
      )
      return false if resp.stacks[0].stack_status == 'REVIEW_IN_PROGRESS'
      true
    rescue Aws::CloudFormation::Errors::ValidationError
      false
    end

    def review_in_progress?
      resp = @client.describe_stacks(
        stack_name: name
      )
      return true if resp.stacks[0].stack_status == 'REVIEW_IN_PROGRESS'
      false
    rescue Aws::CloudFormation::Errors::ValidationError
      false
    end

    def available_change_set?
      resp = @client.describe_change_set(
        change_set_name: change_set_name,
        stack_name: name
      )
      return true if resp.execution_status == 'AVAILABLE'
      false
    rescue Aws::CloudFormation::Errors::ChangeSetNotFound
      false
    end

    def report
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info('*****************************************************'.color(:green))
      CFnDK.logger.info(('stack: ' + name).color(:green))
      CFnDK.logger.info('*****************************************************'.color(:green))
      CFnDK.logger.info('')
      begin
        resp = @client.describe_stacks(
          stack_name: name
        ).stacks[0]
        CFnDK.logger.info('Status: '.color(:green) + colored_status(resp.stack_status))
        CFnDK.logger.info('Reason: '.color(:green) + resp.stack_status_reason) if resp.stack_status_reason
        if @option[:types].instance_of?(Array) && @option[:types].include?('tag')
          CFnDK.logger.info('Tags:'.color(:green))
          tags_rows = resp.tags.map do |item|
            [
              item.key,
              item.value,
            ]
          end
          unless tags_rows.empty?
            table = Terminal::Table.new headings: %w(Key Value), rows: tags_rows
            CFnDK.logger.info table
          end
        end
        if @option[:types].instance_of?(Array) && @option[:types].include?('parameter')
          CFnDK.logger.info('Parameters:'.color(:green))
          parameter_rows = resp.parameters.map do |item|
            [
              item.parameter_key,
              item.parameter_value,
              item.use_previous_value,
              item.resolved_value,
            ]
          end
          unless parameter_rows.empty?
            table = Terminal::Table.new headings: ['Key', 'Value', 'Use Previous Value', 'Resolved Value'], rows: parameter_rows
            CFnDK.logger.info table
          end
        end
        if @option[:types].instance_of?(Array) && @option[:types].include?('output')
          CFnDK.logger.info('Outputs:'.color(:green))
          output_rows = resp.outputs.map do |item|
            [
              item.output_key,
              item.output_value,
              item.export_name,
              item.description,
            ]
          end
          unless output_rows.empty?
            table = Terminal::Table.new headings: ['Key', 'Value', 'Export Name', 'Description'], rows: output_rows
            CFnDK.logger.info table
          end
        end
      rescue Aws::CloudFormation::Errors::ValidationError => ex
        CFnDK.logger.warn "#{ex.class}: #{ex.message}".color(:red)
      end
      if @option[:types].instance_of?(Array) && @option[:types].include?('resource')
        begin
          CFnDK.logger.info('Resources:'.color(:green))
          rows = @client.describe_stack_resources(
            stack_name: name
          ).stack_resources.map do |item|
            [
              item.logical_resource_id,
              item.physical_resource_id,
              item.resource_type,
              item.timestamp,
              colored_status(item.resource_status),
              item.resource_status_reason,
              item.description,
            ]
          end
          unless rows.empty?
            table = Terminal::Table.new headings: %w(Logical Physical Type Timestamp Status Reason Desc), rows: rows
            CFnDK.logger.info table
          end
        rescue Aws::CloudFormation::Errors::ValidationError => ex
          CFnDK.logger.warn "#{ex.class}: #{ex.message}".color(:red)
        end
      end
      if @option[:types].instance_of?(Array) && @option[:types].include?('event')
        CFnDK.logger.info('Events:'.color(:green))
        begin
          rows = @client.describe_stack_events(
            stack_name: name
          ).stack_events.map do |item|
            [
              item.resource_type,
              item.timestamp,
              colored_status(item.resource_status),
              item.resource_status_reason,
            ]
          end
          unless rows.empty?
            table = Terminal::Table.new headings: %w(Type Time Status Reason), rows: rows
            CFnDK.logger.info table
          end
        rescue Aws::CloudFormation::Errors::ValidationError => ex
          CFnDK.logger.warn "#{ex.class}: #{ex.message}".color(:red)
        end
      end
    end

    def name
      [@name, @option[:uuid]].compact.join('-')
    end

    def change_set_name
      [@name, @option[:change_set_uuid]].compact.join('-')
    end

    def template_body
      File.open(@template_file, 'r').read
    end

    def large_template?
      File.size(@template_file) > 51200
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

    def upload_template_file
      bucket = @region + '-' + @global_config.s3_template_bucket
      begin
        @s3_client.head_bucket(bucket: bucket)
      rescue Aws::S3::Errors::NotFound
        @s3_client.create_bucket(bucket: bucket)
        CFnDK.logger.debug('Creatt S3 bucket: ' + bucket)
        @s3_client.put_bucket_lifecycle_configuration(
          bucket: bucket,
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
      key = [@global_config.s3_template_hash, @template_file].compact.join('/')
      @s3_client.put_object(
        body: template_body,
        bucket: bucket,
        key: key
      )
      url = "https://s3.amazonaws.com/#{bucket}/#{key}"
      CFnDK.logger.debug('Put S3 object: ' + url)
      url
    end

    def colored_status(str)
      case str
      when 'CREATE_FAILED' then
        str.color :red
      when 'ROLLBACK_IN_PROGRESS' then
        str.color :red
      when 'ROLLBACK_COMPLETE' then
        str.color :red
      when 'CREATE_COMPLETE' then
        str.color :green
      when 'DELETE_COMPLETE' then
        str.color :gray
      else
        str.color :orange
      end
    end

    def eval_override_parameter(k, v)
      if @override_parameters[k]
        CFnDK::ErbString.new(@override_parameters[k], @option).value
      else
        v
      end
    end
  end
end
