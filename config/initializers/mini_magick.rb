# frozen_string_literal: true

# ImageMagick v7 replaced the standalone `convert` binary with `magick`.
# Tell MiniMagick to use the v7 CLI so image processing doesn't fail.
Rails.application.config.after_initialize do
  require 'mini_magick'
  MiniMagick.configure do |config|
    config.cli = :imagemagick7
  end
end
