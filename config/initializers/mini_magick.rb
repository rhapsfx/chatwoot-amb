# frozen_string_literal: true

# Prefer ImageMagick v7 (`magick`) when available; fall back to legacy `convert` (IM6).
require 'mini_magick'

magick_in_path = (ENV.fetch('PATH', '').split(File::PATH_SEPARATOR) + %w[/opt/homebrew/bin /usr/local/bin /usr/bin]).uniq.any? do |dir|
  File.executable?(File.join(dir, 'magick'))
end

if magick_in_path
  MiniMagick.configure { |c| c.cli = :imagemagick7 }

  # IM7 prints a deprecation warning for `magick convert` — it wants just `magick`.
  # ImageProcessing::MiniMagick hardcodes MiniMagick::Tool::Convert, which builds
  # ["magick", "convert", ...] in imagemagick7 mode. Override executable to drop
  # the subcommand so the command is simply ["magick", ...].
  require 'mini_magick/tool/convert'
  MiniMagick::Tool::Convert.prepend(Module.new do
    def executable
      MiniMagick.imagemagick7? ? ['magick'] : super
    end
  end)
end
