module CFnDK
  class Logger < Logger
    def initialize(option)
      super(STDOUT)
      self.formatter = proc { |severity, datetime, progname, message|
        message.to_s.split(/\n/).map { |line|
          "#{datetime} #{severity} #{line}\n"
        }.join
      }
      self.datetime_format = '%Y-%m-%dT%H:%M:%S'
    end
  end
end
