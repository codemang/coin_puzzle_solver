class Logger
  def self.log(message)
    puts message unless ENV['IS_LOGGING_DISABLED'] == 'true'
  end
end
