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

# Logs whenever a job is pulled off Redis for execution.
class ChatwootDequeuedLogger
  def call(_worker, job, queue)
    payload = job['args'].first
    Sidekiq.logger.info("Dequeued #{job['wrapped']} #{payload['job_id']} from #{queue}")
    yield
  end
end

Sidekiq.configure_server do |config|
  config.redis = Redis::Config.app

  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_SIDEKIQ_DEQUEUE_LOGGER', false))
    config.server_middleware do |chain|
      chain.add ChatwootDequeuedLogger
    end
  end

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
