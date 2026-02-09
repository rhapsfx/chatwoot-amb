module Enterprise::Concerns::Attachment
  extend ActiveSupport::Concern

  included do
    after_create_commit :enqueue_audio_transcription
  end

  private

  def enqueue_audio_transcription
    return unless file_type.to_sym == :audio
    # Skip automatic transcription for Apple Messages - handled manually after file attachment
    return if apple_messages_channel?

    Messages::AudioTranscriptionJob.perform_later(id)
  end

  def apple_messages_channel?
    message&.inbox&.channel_type == 'Channel::AppleMessagesForBusiness'
  end
end
