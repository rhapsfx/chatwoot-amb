class Messages::AudioTranscriptionService < Llm::BaseOpenAiService
  attr_reader :attachment, :message, :account

  def initialize(attachment)
    super()
    @attachment = attachment
    @message = attachment.message
    @account = message.account
  end

  def perform
    return { error: 'Transcription limit exceeded' } unless can_transcribe?
    return { error: 'Message not found' } if message.blank?

    transcriptions = transcribe_audio
    Rails.logger.info "Audio transcription successful: #{transcriptions}"
    { success: true, transcriptions: transcriptions }
  end

  private

  def can_transcribe?
    return false unless account.feature_enabled?('captain_integration')
    return false if account.audio_transcriptions.blank?

    account.usage_limits[:captain][:responses][:current_available].positive?
  end

  def fetch_audio_file
    temp_dir = Rails.root.join('tmp/uploads')
    FileUtils.mkdir_p(temp_dir)
    temp_file_path = File.join(temp_dir, attachment.file.filename.to_s)
    File.write(temp_file_path, attachment.file.download, mode: 'wb')

    # Convert AMR to MP3 if needed (OpenAI Whisper doesn't support AMR)
    if attachment.file.content_type == 'audio/amr' || temp_file_path.end_with?('.amr')
      Rails.logger.info "[AudioTranscription] Converting AMR to MP3: #{temp_file_path}"
      converted_path = convert_amr_to_mp3(temp_file_path)
      FileUtils.rm_f(temp_file_path) # Clean up original AMR file
      return converted_path
    end

    temp_file_path
  end

  def convert_amr_to_mp3(amr_file_path)
    mp3_file_path = amr_file_path.gsub(/\.amr$/, '.mp3')

    # Use ffmpeg to convert AMR to MP3
    # -y: overwrite output file if it exists
    # -i: input file
    # -ar 16000: set audio sample rate to 16kHz (good for speech)
    # -ac 1: set audio channels to mono
    # -b:a 64k: set audio bitrate to 64kbps
    command = "ffmpeg -y -i #{Shellwords.escape(amr_file_path)} -ar 16000 -ac 1 -b:a 64k #{Shellwords.escape(mp3_file_path)} 2>&1"

    Rails.logger.info "[AudioTranscription] Running ffmpeg: #{command}"
    output = `#{command}`

    unless File.exist?(mp3_file_path)
      Rails.logger.error "[AudioTranscription] ffmpeg conversion failed: #{output}"
      raise "Failed to convert AMR to MP3: #{output}"
    end

    Rails.logger.info "[AudioTranscription] Successfully converted AMR to MP3: #{mp3_file_path}"
    mp3_file_path
  end

  def transcribe_audio
    transcribed_text = attachment.meta&.[]('transcribed_text') || ''
    return transcribed_text if transcribed_text.present?

    temp_file_path = fetch_audio_file

    begin
      response = @client.audio.transcribe(
        parameters: {
          model: 'whisper-1',
          file: File.open(temp_file_path),
          temperature: 0.4
        }
      )

      update_transcription(response['text'])
      response['text']
    ensure
      # Clean up temporary file (could be original or converted MP3)
      FileUtils.rm_f(temp_file_path)
    end
  end

  def update_transcription(transcribed_text)
    return if transcribed_text.blank?

    attachment.update!(meta: { transcribed_text: transcribed_text })
    message.reload.send_update_event
    message.account.increment_response_usage

    return unless ChatwootApp.advanced_search_allowed?

    message.reindex
  end
end
