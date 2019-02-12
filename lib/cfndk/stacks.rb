module CFnDK
  class Stacks
    def initialize(data, option, cfn_client)
      @option = option
      @cfn_client = cfn_client
      create_stack data
      create_sequence
    end

    def create
      @sequence.each do |stacks|
        stacks.each do |name|
          puts(('creating ' + name).color(:green))
          puts('Name        :' + @stacks[name].name) if @option[:v]
          puts('Parametres  :' + @stacks[name].parameters.inspect) if @option[:v]
          puts('Capabilities:' + @stacks[name].capabilities.inspect) if @option[:v]
          puts('timeout     :' + @stacks[name].timeout_in_minutes.to_s) if @option[:v]
          @cfn_client.create_stack(
            stack_name: @stacks[name].name,
            template_body: @stacks[name].template_body,
            parameters: @stacks[name].parameters,
            capabilities: @stacks[name].capabilities,
            timeout_in_minutes: @stacks[name].timeout_in_minutes
          )
        end
        stacks.each do |name|
          begin
            @cfn_client.wait_until(
              :stack_create_complete,
              stack_name: @stacks[name].name
            )
            puts(('created ' + name).color(:green))
          rescue Aws::Waiters::Errors::FailureStateError => ex
            puts ex.message
            report_event
            raise ex
          end
        end
      end
    end

    def update
      @sequence.each do |stacks|
        updating_stacks = []
        stacks.each do |name|
          puts(('updating ' + name).color(:green))
          puts('Name        :' + @stacks[name].name) if @option[:v]
          puts('Parametres  :' + @stacks[name].parameters.inspect) if @option[:v]
          puts('Capabilities:' + @stacks[name].capabilities.inspect) if @option[:v]
          puts('timeout     :' + @stacks[name].timeout_in_minutes.to_s) if @option[:v]
          begin
            @cfn_client.update_stack(
              stack_name: @stacks[name].name,
              template_body: @stacks[name].template_body,
              parameters: @stacks[name].parameters,
              capabilities: @stacks[name].capabilities
            )
            updating_stacks.push name
          rescue Aws::CloudFormation::Errors::ValidationError => ex
            puts ex.message.color :red
          end
        end
        updating_stacks.each do |name|
          @cfn_client.wait_until(
            :stack_update_complete,
            stack_name: @stacks[name].name
          )
          puts(('updated ' + name).color(:green))
        end
      end
    end

    def create_or_changeset
      @sequence.each do |stacks|
        create_stacks = []
        changeset_stacks = []
        stacks.each do |name|
          begin
            @cfn_client.describe_stacks(
              stack_name: @stacks[name].name
            )
            puts(('creating ' + name + @option[:uuid]).color(:green))
            puts('Name        :' + @stacks[name].name) if @option[:v]
            puts('Parametres  :' + @stacks[name].parameters.inspect) if @option[:v]
            puts('Capabilities:' + @stacks[name].capabilities.inspect) if @option[:v]
            @cfn_client.create_change_set(
              stack_name: @stacks[name].name,
              template_body: @stacks[name].template_body,
              parameters: @stacks[name].parameters,
              capabilities: @stacks[name].capabilities,
              change_set_name:  @stacks[name].name + @option[:uuid]
            )
            changeset_stacks.push name
          rescue Aws::CloudFormation::Errors::ValidationError
            puts(('creating ' + name).color(:green))
            puts('Name        :' + @stacks[name].name) if @option[:v]
            puts('Parametres  :' + @stacks[name].parameters.inspect) if @option[:v]
            puts('Capabilities:' + @stacks[name].capabilities.inspect) if @option[:v]
            puts('timeout     :' + @stacks[name].timeout_in_minutes.to_s) if @option[:v]
            @cfn_client.create_stack(
              stack_name: @stacks[name].name,
              template_body: @stacks[name].template_body,
              parameters: @stacks[name].parameters,
              capabilities: @stacks[name].capabilities,
              timeout_in_minutes: @stacks[name].timeout_in_minutes
            )
            create_stacks.push name
          end
        end
        create_stacks.each do |name|
          @cfn_client.wait_until(
            :stack_create_complete,
            stack_name: @stacks[name].name
          )
          puts(('created ' + name).color(:green))
        end
        changeset_stacks.each do |name|
          begin
            @cfn_client.wait_until(
              :change_set_create_complete,
              stack_name: @stacks[name].name,
              change_set_name: @stacks[name].name + @option[:uuid]
            )
            puts(('created ' + @stacks[name].name + @option[:uuid]).color(:green))
          rescue Aws::Waiters::Errors::FailureStateError => ex
            resp = @cfn_client.describe_change_set(
              change_set_name: @stacks[name].name + @option[:uuid],
              stack_name: @stacks[name].name
            )
            if resp.status_reason != "The submitted information didn't contain changes. Submit different information to create a change set."
              puts ex.message.color :red
              raise ex
            else
              puts(('failed ' + @stacks[name].name + @option[:uuid]).color(:red))
              puts resp.status_reason
              @cfn_client.delete_change_set(
                change_set_name: @stacks[name].name + @option[:uuid],
                stack_name: @stacks[name].name
              )
              puts(('deleted ' + @stacks[name].name + @option[:uuid]).color(:red))
            end
          end
        end
      end
    end

    def report_stack
      rows = @sequence.flat_map do |stacks|
        stacks.flat_map do |name|
          rows = []
          begin
            rows = @cfn_client.describe_stacks(
              stack_name: @stacks[name].name
            ).stacks.map do |item|
              [
                item.stack_name,
                item.creation_time,
                item.deletion_time,
                case item.stack_status
                when 'CREATE_FAILED' then
                  item.stack_status.color :red
                when 'ROLLBACK_IN_PROGRESS' then
                  item.stack_status.color :red
                when 'ROLLBACK_COMPLETE' then
                  item.stack_status.color :red
                when 'CREATE_COMPLETE' then
                  item.stack_status.color :green
                when 'DELETE_COMPLETE' then
                  item.stack_status.color :gray
                else
                  item.stack_status.color :orange
                end,
                item.stack_status_reason]
            end
          rescue Aws::CloudFormation::Errors::ValidationError => ex
            puts ex.message
          end
          rows
        end
      end
      table = Terminal::Table.new headings: %w(Name Creation Deletion Status Reason), rows: rows
      puts table
    end

    def report_stack_resource
      @sequence.each do |stacks|
        stacks.each do |name|
          puts(('stack ' + name).color(:green))
          puts('Name        :' + @stacks[name].name) if @option[:v]
          begin
            rows = @cfn_client.describe_stack_resources(
              stack_name: @stacks[name].name
            ).stack_resources.map do |item|
              [
                item.logical_resource_id,
                item.physical_resource_id,
                item.resource_type,
                item.timestamp,
                case item.resource_status
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
                end,
                item.resource_status_reason,
                item.description,
              ]
            end
            table = Terminal::Table.new headings: %w(L-name P-name Type Timestamp Status Reason Desc), rows: rows
            puts table
          rescue Aws::CloudFormation::Errors::ValidationError => ex
            puts ex.message
          end
        end
      end
    end

    def report_event
      @sequence.each do |stacks|
        stacks.each do |name|
          puts(('stack ' + name).color(:green))
          puts('Name        :' + @stacks[name].name) if @option[:v]
          begin
            rows = @cfn_client.describe_stack_events(
              stack_name: @stacks[name].name
            ).stack_events.map do |item|
              [
                item.resource_type,
                item.timestamp,
                case item.resource_status
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
                end,
                item.resource_status_reason]
            end
            table = Terminal::Table.new headings: %w(Type Time Status Reason), rows: rows
            puts table
          rescue Aws::CloudFormation::Errors::ValidationError => ex
            puts ex.message
          end
        end
      end
    end

    def destroy
      @sequence.reverse_each do |stacks|
        stacks.each do |name|
          puts(('deleting ' + name).color(:green))
          puts('Name        :' + @stacks[name].name) if @option[:v]
          @cfn_client.delete_stack(
            stack_name: @stacks[name].name
          )
        end
        stacks.each do |name|
          @cfn_client.wait_until(
            :stack_delete_complete,
            stack_name: @stacks[name].name
          )
          puts(('deleted ' + name).color(:green))
        end
      end
    end

    private

    def create_stack(data)
      @stacks = {}
      data['stacks'].each do |name, properties|
        @stacks[name] = Stack.new(name, properties, @option)
      end
    end

    def create_sequence
      @sequence = []
      names_of_upprocessed_stack = @stacks.keys
      names_of_processed_stack = []
      until names_of_upprocessed_stack.empty?
        names = names_of_upprocessed_stack.select do |name|
          @stacks[name].depends.all? do |depend_name|
            names_of_processed_stack.include? depend_name
          end
        end
        raise 'There are cyclic dependency.' if names.empty?
        names_of_processed_stack += names
        names_of_upprocessed_stack -= names
        @sequence.push names
      end
    end
  end
end
