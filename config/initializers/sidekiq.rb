require Rails.root.join('lib/redis/config')

schedule_file = 'config/schedule.yml'

Sidekiq.configure_client do |config|
  config.redis = Redis::Config.app

  # Route client logs (Enqueued messages) to separate file in development
  if Rails.env.development?
    log_file = File.open(Rails.root.join('log/sidekiq.log'), 'a')
    log_file.set_encoding('UTF-8')
    config.logger = Logger.new(log_file)
    config.logger.level = Logger::INFO
    # Skip verbose job logging (prevents "Enqueued JobName with arguments:" logs)
    config[:skip_default_job_logging] = true
  end
end

Sidekiq.configure_server do |config|
  config.redis = Redis::Config.app

  # skip the default start stop logging
  if Rails.env.production?
    config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    config[:skip_default_job_logging] = true
    config.logger.level = Logger.const_get(ENV.fetch('LOG_LEVEL', 'info').upcase.to_s)
  elsif Rails.env.development?
    # Route Sidekiq logs to separate file to avoid polluting development.log
    log_file = File.open(Rails.root.join('log/sidekiq.log'), 'a')
    log_file.set_encoding('UTF-8')
    config.logger = Logger.new(log_file)
    config.logger.level = Logger::INFO
    # Skip verbose job logging (prevents "Performing JobName with arguments:" logs)
    config[:skip_default_job_logging] = true
  end
end

# https://github.com/ondrejbartas/sidekiq-cron
Rails.application.reloader.to_prepare do
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file) if File.exist?(schedule_file) && Sidekiq.server?
end
