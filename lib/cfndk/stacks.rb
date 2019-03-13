module CFnDK
  class Stacks
    def initialize(data, option, credentials)
      @option = option
      @credentials = credentials

      prepare_stack(data)
      prepare_sequence
    end

    def create
      @sequence.each do |stacks|
        stacks.each do |name|
          @stacks[name].create
        end
        stacks.each do |name|
          @stacks[name].wait_until_create
        end
      end
    end

    def update
      @sequence.each do |stacks|
        updating_stacks = []
        stacks.each do |name|
          result = @stacks[name].update
          updating_stacks.push name if result
        end
        updating_stacks.each do |name|
          @stacks[name].wait_until_update
        end
      end
    end

    def destroy
      @sequence.reverse_each do |stacks|
        stacks.each do |name|
          @stacks[name].destroy
        end
        stacks.each do |name|
          @stacks[name].wait_until_destroy
        end
      end
    end

    def validate
      @sequence.each do |stacks|
        stacks.each do |name|
          @stacks[name].validate
        end
      end
    end

    def create_change_set
      @sequence.each do |stacks|
        stacks.each do |name|
          @stacks[name].create_change_set
        end
        stacks.each do |name|
          @stacks[name].wait_until_create_change_set
        end
      end
    end

    def execute_change_set
      @sequence.each do |stacks|
        created_stacks = []
        stacks.each do |name|
          created_stacks.push(name) if @stacks[name].created?
          @stacks[name].execute_change_set
        end
        stacks.each do |name|
          if created_stacks.include?(name)
            @stacks[name].wait_until_update
          else
            @stacks[name].wait_until_create
          end
        end
      end
    end

    def delete_change_set
      @sequence.reverse_each do |stacks|
        stacks.each do |name|
          @stacks[name].delete_change_set
        end
      end
    end

    def report_change_set
      @sequence.each do |stacks|
        stacks.each do |name|
          @stacks[name].report_change_set
        end
      end
    end

    def report
      @sequence.each do |stacks|
        stacks.each do |name|
          @stacks[name].report
        end
      end
    end

    private

    def prepare_stack(data)
      @stacks = {}
      return unless data['stacks'].is_a?(Hash)
      data['stacks'].each do |name, properties|
        @stacks[name] = Stack.new(name, properties, @option, @credentials)
      end
    end

    def prepare_sequence
      @sequence = []
      names_of_upprocessed_stack = @stacks.keys
      names_of_processed_stack = []
      until names_of_upprocessed_stack.empty?
        names = names_of_upprocessed_stack.select do |name|
          @stacks[name].depends.all? do |depend_name|
            names_of_processed_stack.include? depend_name
          end
        end
        raise "There are cyclic dependency or stack doesn't exist. unprocessed_stack: " + names_of_upprocessed_stack.join(',') if names.empty?
        names_of_processed_stack += names
        names_of_upprocessed_stack -= names
        @sequence.push names
      end
    end
  end
end
