# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utf8 do
  describe ".ensure" do
    it "relabels ASCII-8BIT UTF-8 bytes as UTF-8" do
      binary = "año".dup.force_encoding(Encoding::ASCII_8BIT)

      result = described_class.ensure(binary)

      expect(result).to eq("año")
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect { result.to_json }.not_to raise_error
    end

    it "leaves a UTF-8 string unchanged" do
      result = described_class.ensure("año")

      expect(result).to eq("año")
      expect(result.encoding).to eq(Encoding::UTF_8)
    end

    it "returns an empty string for nil" do
      expect(described_class.ensure(nil)).to eq("")
    end

    it "replaces invalid byte sequences" do
      invalid = "hello\xFFworld".dup.force_encoding(Encoding::ASCII_8BIT)

      result = described_class.ensure(invalid)

      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to eq(true)
      expect(result).to eq("hello?world")
    end
  end
end
