module CFnDK
  class Logger < Logger
    def initialize(option)
      super(STDOUT)
      self.level = Logger::INFO unless option[:v]
      self.formatter = proc { |severity, datetime, progname, message|
        message.to_s.split(/\n/).map do |line|
          "#{datetime} #{severity} #{line}\n"
        end.join
      }
      self.datetime_format = '%Y-%m-%dT%H:%M:%S'
    end
  end
end
