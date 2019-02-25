module CFnDK
  def self.logger
    @logger = CFnDKLogger.new({}) if  @logger.nil?
    @logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  class CFnDKLogger < Logger
    def initialize(options)
      super(STDOUT)
      self.level = Logger::INFO unless options[:v]
      self.formatter = proc { |severity, datetime, progname, message|
        message.to_s.split(/\n/).map do |line|
          "#{datetime} #{severity} #{line}\n"
        end.join
      }
      self.datetime_format = '%Y-%m-%dT%H:%M:%S'
    end
  end
end
