module CFnDK
  class Stack
    attr_reader :template_file, :parameter_input, :capabilities, :depends, :timeout_in_minutes
    def initialize(name, data, option, credentials)
      @name = name
      @template_file = data['template_file'] || ''
      @parameter_input = data['parameter_input'] || ''
      @capabilities = data['capabilities'] || []
      @depends = data['depends'] || []
      @timeout_in_minutes = data['timeout_in_minutes'] || 1
      @override_parameters = data['parameters'] || {}
      @option = option
      @client = Aws::CloudFormation::Client.new(credentials: credentials)
    end

    def create
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('creating stack: ' + name).color(:green))
      CFnDK.logger.debug('Name        :' + name)
      CFnDK.logger.debug('Parametres  :' + parameters.inspect)
      CFnDK.logger.debug('Capabilities:' + capabilities.inspect)
      CFnDK.logger.debug('Timeout     :' + timeout_in_minutes.to_s)
      tags = [
        {
          key: 'origina_name',
          value: @name,
        }
      ]
      tags.push(
        {
          key: 'UUID',
          value: @option[:uuid],
        }
      ) if @option[:uuid]
      @client.create_stack(
        stack_name: name,
        template_body: template_body,
        parameters: parameters,
        capabilities: capabilities,
        timeout_in_minutes: timeout_in_minutes,
        tags: tags,
      )
    end

    def wait_until_create
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      begin
        @client.wait_until(
          :stack_create_complete,
          stack_name: name
        )
        CFnDK.logger.info(('created stack: ' + name).color(:green))
      rescue Aws::Waiters::Errors::FailureStateError => ex
        CFnDK.logger.error ex.message
        report_event
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
      begin
        @client.update_stack(
          stack_name: name,
          template_body: template_body,
          parameters: parameters,
          capabilities: capabilities
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
      @client.wait_until(
        :stack_update_complete,
        stack_name: name
      )
      CFnDK.logger.info(('updated stack: ' + name).color(:green))
    end

    def destroy
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      if exits?
        CFnDK.logger.info(('deleting stack: ' + name).color(:green))
        CFnDK.logger.debug('Name        :' + name)
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
      @client.wait_until(
        :stack_delete_complete,
        stack_name: name
      )
      CFnDK.logger.info(('deleted stack: ' + name).color(:green))
    end

    def create_change_set
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      CFnDK.logger.info(('creating change set: ' + name).color(:green))
      CFnDK.logger.debug('Name        :' + name)
      CFnDK.logger.debug('Parametres  :' + parameters.inspect)
      CFnDK.logger.debug('Capabilities:' + capabilities.inspect)
      @client.create_change_set(
        stack_name: name,
        template_body: template_body,
        parameters: parameters,
        capabilities: capabilities,
        change_set_name: name
      )
    end

    def wait_until_create_change_set
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      begin
        @client.wait_until(
          :change_set_create_complete,
          stack_name: name,
          change_set_name: name
        )
        CFnDK.logger.info(('created chnage set: ' + name).color(:green))
      rescue Aws::Waiters::Errors::FailureStateError => ex
        resp = @client.describe_change_set(
          change_set_name: name,
          stack_name: name
        )
        if resp.status_reason != "The submitted information didn't contain changes. Submit different information to create a change set."
          CFnDK.logger.error ex.message.color(:red)
          raise ex
        else
          CFnDK.logger.error(('failed create change set: ' + name).color(:red))
          CFnDK.logger.error resp.status_reason
          @client.delete_change_set(
            change_set_name: name,
            stack_name: name
          )
          CFnDK.logger.info(('deleted change set: ' + name).color(:red))
        end
      end
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
        CFnDK.logger.info(('Status: ').color(:green) + colored_status(resp.stack_status))
        CFnDK.logger.info(('Reason: ').color(:green) + resp.stack_status_reason) if resp.stack_status_reason
        if @option[:types].instance_of?(Array) && @option[:types].include?('tag')
          CFnDK.logger.info(('Tags:').color(:green))
          tags_rows = resp.tags.map do |item|
            [
              item.key,
              item.value,
            ]
          end
          if tags_rows.size > 0
            table = Terminal::Table.new headings: ['Key', 'Value'], rows: tags_rows
            CFnDK.logger.info table
          end
        end
        if @option[:types].instance_of?(Array) && @option[:types].include?('parameter')
          CFnDK.logger.info(('Parameters:').color(:green))
          parameter_rows = resp.parameters.map do |item|
            [
              item.parameter_key,
              item.parameter_value,
              item.use_previous_value,
              item.resolved_value,
            ]
          end
          if parameter_rows.size > 0
            table = Terminal::Table.new headings: ['Key', 'Value', 'Use Previous Value', 'Resolved Value'], rows: parameter_rows
            CFnDK.logger.info table
          end
        end
        if @option[:types].instance_of?(Array) && @option[:types].include?('output')
          CFnDK.logger.info(('Outputs:').color(:green))
          output_rows = resp.outputs.map do |item|
            [
              item.output_key,
              item.output_value,
              item.export_name,
              item.description,
            ]
          end
          if output_rows.size > 0
            table = Terminal::Table.new headings: ['Key', 'Value', 'Export Name', 'Description'], rows: output_rows
            CFnDK.logger.info table
          end
        end
      rescue Aws::CloudFormation::Errors::ValidationError => ex
        CFnDK.logger.warn ex.message
      end
      if @option[:types].instance_of?(Array) && @option[:types].include?('resource')
        begin      
          CFnDK.logger.info(('Resources:').color(:green))    
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
          if rows.size > 0
            table = Terminal::Table.new headings: %w(Logical Physical Type Timestamp Status Reason Desc), rows: rows
            CFnDK.logger.info table
          end
        rescue Aws::CloudFormation::Errors::ValidationError => ex
          CFnDK.logger.warn ex.message
        end
      end
      if @option[:types].instance_of?(Array) && @option[:types].include?('event')
        CFnDK.logger.info(('Events:').color(:green))
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
          if rows.size > 0
            table = Terminal::Table.new headings: %w(Type Time Status Reason), rows: rows
            CFnDK.logger.info table
          end
        rescue Aws::CloudFormation::Errors::ValidationError => ex
          CFnDK.logger.warn ex.message
        end
      end
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
