# frozen_string_literal: true

require "rails_helper"

RSpec.describe SandboxAccessTokenCheckin, type: :model do
  describe "validations" do
    it "accepts a complete check-in" do
      checkin = build(:sandbox_access_token_checkin)

      expect(checkin).to be_valid
    end

    it "requires first_name, last_name, id_type, and document_number" do
      checkin = described_class.new

      expect(checkin).not_to be_valid
      expect(checkin.errors[:first_name]).to be_present
      expect(checkin.errors[:last_name]).to be_present
      expect(checkin.errors[:id_type]).to be_present
      expect(checkin.errors[:document_number]).to be_present
    end

    it "requires ip_address to persist" do
      checkin = build(:sandbox_access_token_checkin, ip_address: nil)

      expect(checkin).not_to be_valid
      expect(checkin.errors[:ip_address]).to be_present
    end

    it "is reviewable without ip_address" do
      checkin = build(:sandbox_access_token_checkin, ip_address: nil)

      expect(checkin).to be_reviewable
    end

    it "rejects the same identity on the same token" do
      token = create(:sandbox_access_token)
      create(:sandbox_access_token_checkin, sandbox_access_token: token, id_type: :dni, document_number: "12345678")
      duplicate = build(:sandbox_access_token_checkin, sandbox_access_token: token, id_type: :dni, document_number: "12345678")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:document_number]).to be_present
    end

    it "allows the same identity on a different token" do
      create(:sandbox_access_token_checkin, id_type: :dni, document_number: "12345678")
      other = build(:sandbox_access_token_checkin, id_type: :dni, document_number: "12345678")

      expect(other).to be_valid
    end
  end

  describe "document_number normalization" do
    it "strips spaces, dots, and dashes before save" do
      checkin = create(:sandbox_access_token_checkin, document_number: " 12.345-678 ")

      expect(checkin.document_number).to eq("12345678")
    end

    it "treats formatted and plain values as the same identity" do
      token = create(:sandbox_access_token)
      create(:sandbox_access_token_checkin, sandbox_access_token: token, id_type: :dni, document_number: "12.345.678")
      duplicate = build(:sandbox_access_token_checkin, sandbox_access_token: token, id_type: :dni, document_number: "12345678")

      expect(duplicate).not_to be_valid
    end
  end

  describe "id_type" do
    it "accepts dni, pasaporte, and legajo" do
      expect(described_class.id_types.keys).to contain_exactly("dni", "pasaporte", "legajo")
    end
  end
end
