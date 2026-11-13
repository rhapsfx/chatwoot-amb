# frozen_string_literal: true

# Shared PNG encoder for Apple Messages for Business.
#
# Apple's spec (v4.2.2) restricts rich-link and interactive-message images to PNG format, with
# interactive-message images additionally capped at 200KB. PNG is lossless, so unlike JPEG there's
# no "quality" knob to shrink an oversized image — instead we step down through palette reduction
# (indexed color depth) and, if that's still not enough, progressive downscaling.
#
# Uses ImageMagick (via MiniMagick/ImageProcessing, already a dependency) for palette quantization.
# No additional dependency (e.g. pngquant) is added here; revisit if real-world testing shows this
# isn't sufficient, particularly for photographic rich-link images.
class AppleMessagesForBusiness::PngEncoderService
  include AppleMessagesForBusiness::Concerns::Utf8Logging

  DEFAULT_MAX_BYTES = 200.kilobytes
  COLOR_LADDER = [256, 128, 64].freeze
  MIN_DIMENSION = 80

  def self.encode(raw_bytes, max_width:, max_height:, max_bytes: DEFAULT_MAX_BYTES)
    new(raw_bytes, max_width: max_width, max_height: max_height, max_bytes: max_bytes).encode
  end

  def initialize(raw_bytes, max_width:, max_height:, max_bytes: DEFAULT_MAX_BYTES)
    @raw_bytes = raw_bytes
    @max_width = max_width
    @max_height = max_height
    @max_bytes = max_bytes
  end

  # Returns the encoded PNG bytes, or nil if the image could not be brought under max_bytes
  # even after the full palette/resize ladder (caller should omit the image rather than send an
  # out-of-spec payload).
  def encode
    source_tmp = write_source_tempfile
    result = convert(source_tmp.path, @max_width, @max_height, colors: nil)
    return result if result.bytesize <= @max_bytes

    result = shrink_via_palette(source_tmp.path, result)
    return result if result && result.bytesize <= @max_bytes

    shrink_via_downscale(source_tmp.path)
  ensure
    source_tmp&.unlink
  end

  private

  def write_source_tempfile
    tmp = Tempfile.new(['amb_png_src', '.bin'])
    tmp.binmode
    tmp.write(@raw_bytes)
    tmp.flush
    tmp.close
    tmp
  end

  def convert(source_path, width, height, colors:)
    processed = ImageProcessing::MiniMagick
                .source(source_path)
                .resize_to_limit(width, height)
                .convert('png')
                # Flatten transparency onto white - PNG keeps alpha, but a consistent background
                # avoids surprises if a downstream consumer doesn't render transparency.
                .custom do |cmd|
                  cmd.background('white').flatten.strip
                  cmd.colors(colors) if colors
                end
                .call

    File.binread(processed.path)
  end

  def shrink_via_palette(source_path, previous_result)
    COLOR_LADDER.each do |colors|
      result = convert(source_path, @max_width, @max_height, colors: colors)
      log_info "[PngEncoder] Palette reduction (colors=#{colors}): #{result.bytesize} bytes"
      return result if result.bytesize <= @max_bytes

      previous_result = result
    end

    previous_result
  end

  def shrink_via_downscale(source_path)
    width = @max_width
    height = @max_height

    until width < MIN_DIMENSION || height < MIN_DIMENSION
      width = (width * 0.8).to_i
      height = (height * 0.8).to_i

      result = convert(source_path, width, height, colors: COLOR_LADDER.last)
      log_info "[PngEncoder] Downscale to #{width}x#{height}: #{result.bytesize} bytes"
      return result if result.bytesize <= @max_bytes
    end

    log_error "[PngEncoder] Could not bring image under #{@max_bytes} bytes even after full palette/resize ladder"
    nil
  end
end
