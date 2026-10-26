# frozen_string_literal: true

# Relabel binary IO (uploads, File.read, Open3) as UTF-8.
# Use force_encoding, not encode: ASCII-8BIT high bytes like "\xC3" (ñ) cannot be transcoded.
module Utf8
  def self.ensure(str)
    return "" if str.nil?

    s = str.to_s.dup
    s.force_encoding(Encoding::UTF_8)
    # encode! to the same encoding is a no-op; scrub! replaces invalid UTF-8 bytes.
    s.scrub!("?") unless s.valid_encoding?
    s
  end
end
