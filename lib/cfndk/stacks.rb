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

    def create_or_changeset
      @sequence.each do |stacks|
        create_stacks = []
        changeset_stacks = []
        stacks.each do |name|
          if @stacks[name].exits?
            @stacks[name].create_change_set
            changeset_stacks.push name
          else
            @stacks[name].create
            create_stacks.push name
          end
        end
        create_stacks.each do |name|
          @stacks[name].wait_until_create
        end
        changeset_stacks.each do |name|
          @stacks[name].wait_until_create_change_set
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
        raise 'There are cyclic dependency or stack is not exit. unprocessed_stack: ' + names_of_upprocessed_stack.join(',') if names.empty?
        names_of_processed_stack += names
        names_of_upprocessed_stack -= names
        @sequence.push names
      end
    end
  end
end
