module CFnDK
  module SubcommandHelpReternable
    module ClassMethods
      def subcommand_help(cmd)
        desc 'help [COMMAND]', 'Describe subcommands or one specific subcommand'
        class_eval "
          def help(command = nil, subcommand = true); super; return 2; end
  "
      end
    end
    extend ClassMethods
    def self.included(klass)
      klass.extend ClassMethods
    end
  end
end