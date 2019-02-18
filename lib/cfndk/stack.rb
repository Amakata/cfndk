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
      @logger = CFnDK::Logger.new(option)
    end

    def create
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('creating stack: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
      @logger.debug('Parametres  :' + parameters.inspect)
      @logger.debug('Capabilities:' + capabilities.inspect)
      @logger.debug('Timeout     :' + timeout_in_minutes.to_s)
      @client.create_stack(
        stack_name: name,
        template_body: template_body,
        parameters: parameters,
        capabilities: capabilities,
        timeout_in_minutes: timeout_in_minutes
      )
    end

    def wait_until_create
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      begin
        @client.wait_until(
          :stack_create_complete,
          stack_name: name
        )
        @logger.info(('created stack: ' + @name).color(:green))
      rescue Aws::Waiters::Errors::FailureStateError => ex
        @logger.error ex.message
        report_event
        raise ex
      end
    end

    def update
      return false if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('updating stack: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
      @logger.debug('Parametres  :' + parameters.inspect)
      @logger.debug('Capabilities:' + capabilities.inspect)
      @logger.debug('Timeout     :' + timeout_in_minutes.to_s)
      begin
        @client.update_stack(
          stack_name: name,
          template_body: template_body,
          parameters: parameters,
          capabilities: capabilities
        )
        true
      rescue Aws::CloudFormation::Errors::ValidationError => ex
        @logger.error ex.message.color(:red)
        false
      end
    end

    def wait_until_update
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @client.wait_until(
        :stack_update_complete,
        stack_name: name
      )
      @logger.info(('updated stack: ' + @name).color(:green))
    end

    def destroy
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('deleting stack: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
      @client.delete_stack(
        stack_name: name
      )
    end

    def wait_until_destroy
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @client.wait_until(
        :stack_delete_complete,
        stack_name: name
      )
      @logger.info(('deleted stack: ' + @name).color(:green))
    end

    def create_change_set
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('creating change set: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
      @logger.debug('Parametres  :' + parameters.inspect)
      @logger.debug('Capabilities:' + capabilities.inspect)
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
        @logger.info(('created chnage set: ' + name).color(:green))
      rescue Aws::Waiters::Errors::FailureStateError => ex
        resp = @client.describe_change_set(
          change_set_name: name,
          stack_name: name
        )
        if resp.status_reason != "The submitted information didn't contain changes. Submit different information to create a change set."
          @logger.error ex.message.color(:red)
          raise ex
        else
          @logger.error(('failed create change set: ' + name).color(:red))
          @logger.error resp.status_reason
          @client.delete_change_set(
            change_set_name: name,
            stack_name: name
          )
          @logger.info(('deleted change set: ' + name).color(:red))
        end
      end
    end

    def validate
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('validate stack: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
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

    def report_stack
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('stack: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
      begin
        rows = @client.describe_stacks(
          stack_name: name
        ).stacks.map do |item|
          [
            item.stack_name,
            item.creation_time,
            item.deletion_time,
            coloerd_status(item.stack_status),
            item.stack_status_reason]
        end
        table = Terminal::Table.new headings: %w(Name Creation Deletion Status Reason), rows: rows
        @logger.info table
      rescue Aws::CloudFormation::Errors::ValidationError => ex
        @logger.warn ex.message
      end
    end

    def report_event
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('stack: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
      begin
        rows = @client.describe_stack_events(
          stack_name: name
        ).stack_events.map do |item|
          [
            item.resource_type,
            item.timestamp,
            coloerd_status(item.resource_status),
            item.resource_status_reason]
        end
        table = Terminal::Table.new headings: %w(Type Time Status Reason), rows: rows
        @logger.info table
      rescue Aws::CloudFormation::Errors::ValidationError => ex
        @logger.warn ex.message
      end
    end

    def report_stack_resource
      return if @option[:stack_names].instance_of?(Array) && !@option[:stack_names].include?(@name)
      @logger.info(('stack: ' + @name).color(:green))
      @logger.debug('Name        :' + name)
      begin
        rows = @client.describe_stack_resources(
          stack_name: name
        ).stack_resources.map do |item|
          [
            item.logical_resource_id,
            item.physical_resource_id,
            item.resource_type,
            item.timestamp,
            coloerd_status(item.resource_status),
            item.resource_status_reason,
            item.description,
          ]
        end
        table = Terminal::Table.new headings: %w(L-name P-name Type Timestamp Status Reason Desc), rows: rows
        @logger.info table
      rescue Aws::CloudFormation::Errors::ValidationError => ex
        @logger.warn ex.message
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

    def coloerd_status(str)
      case str
      when 'CREATE_FAILED' then
        item.resource_status.color :red
      when 'ROLLBACK_IN_PROGRESS' then
        item.resource_status.color :red
      when 'ROLLBACK_COMPLETE' then
        item.resource_status.color :red
      when 'CREATE_COMPLETE' then
        item.resource_status.color :green
      when 'DELETE_COMPLETE' then
        item.resource_status.color :gray
      else
        item.resource_status.color :orange
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
