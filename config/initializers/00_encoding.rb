# frozen_string_literal: true

# Set default encodings for the entire Ruby process
# This must run before any other initializers (hence the 00_ prefix)
# to ensure all log output uses UTF-8 encoding

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Ensure STDOUT and STDERR use UTF-8
$stdout.set_encoding(Encoding::UTF_8)
$stderr.set_encoding(Encoding::UTF_8)
