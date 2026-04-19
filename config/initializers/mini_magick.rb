# frozen_string_literal: true

# Prefer ImageMagick v7 when `magick` exists, but fall back to the legacy
# `convert` CLI in environments where only ImageMagick 6 is installed.
Rails.application.config.after_initialize do
  require 'mini_magick'
  MiniMagick.configure do |config|
    config.cli = File.executable?('/usr/bin/magick') || File.executable?('/bin/magick') ? :imagemagick7 : :imagemagick
  end
end
