# frozen_string_literal: true

require "rails_helper"

RSpec.describe SandboxAccessToken, type: :model do
  describe "validations" do
    let(:owner) { create(:user) }

    it "assigns a long token on create" do
      language = create(:programming_language)
      token = described_class.new(user: owner, valid_from: 1.minute.ago, expires_at: 2.hours.from_now)
      token.programming_languages << language
      token.save!

      expect(token.token).to be_present
      expect(token.token.length).to be >= 20
    end

    it "rejects a token with no languages" do
      token = described_class.new(user: owner, valid_from: 1.minute.ago, expires_at: 2.hours.from_now)

      expect(token).not_to be_valid
      expect(token.errors[:programming_languages]).to include("must include at least one language")
    end

    it "rejects an expiry in the past on create" do
      token = described_class.new(user: owner, valid_from: 2.hours.ago, expires_at: 1.hour.ago)

      expect(token).not_to be_valid
      expect(token.errors[:expires_at]).to include("must be in the future")
    end

    it "rejects an expiry in the past on update" do
      token = create(:sandbox_access_token)

      token.expires_at = 1.minute.ago

      expect(token).not_to be_valid
      expect(token.errors[:expires_at]).to include("must be in the future")
    end

    it "rejects an expiry that is not after valid_from" do
      token = described_class.new(user: owner, valid_from: 2.hours.from_now, expires_at: 1.hour.from_now)

      expect(token).not_to be_valid
      expect(token.errors[:expires_at]).to include("must be after valid from")
    end
  end

  describe "#live?" do
    it "is true inside the valid window" do
      token = create(:sandbox_access_token, valid_from: 1.hour.ago, expires_at: 1.hour.from_now)

      expect(token.live?).to be(true)
    end

    it "is false before valid_from" do
      token = create(:sandbox_access_token, :upcoming)

      expect(token.live?).to be(false)
      expect(token.upcoming?).to be(true)
    end

    it "is false after expire!" do
      token = create(:sandbox_access_token)

      token.expire!

      expect(token.live?).to be(false)
      expect(token.revoked?).to be(true)
    end

    it "is false when expires_at is in the past" do
      token = create(:sandbox_access_token, :expired)

      expect(token.live?).to be(false)
    end
  end

  describe "#expire!" do
    it "does not change revoked_at when already revoked" do
      token = create(:sandbox_access_token, :revoked)
      original = token.revoked_at

      token.expire!

      expect(token.revoked_at).to eq(original)
    end
  end

  describe "#expirable?" do
    it "is true for upcoming tokens" do
      token = create(:sandbox_access_token, :upcoming)

      expect(token.expirable?).to be(true)
    end

    it "is false for expired tokens" do
      token = create(:sandbox_access_token, :expired)

      expect(token.expirable?).to be(false)
    end
  end

  describe ".for_admin_list" do
    it "orders by valid_from and puts expired or revoked last" do
      expired = create(:sandbox_access_token, :expired, valid_from: 5.days.ago)
      revoked = create(:sandbox_access_token, :revoked, valid_from: 2.hours.from_now, expires_at: 4.hours.from_now)
      later_start = create(:sandbox_access_token, :upcoming, label: "Later", valid_from: 2.days.from_now, expires_at: 9.days.from_now)
      earlier_start = create(:sandbox_access_token, valid_from: 1.hour.ago, expires_at: 3.hours.from_now)

      expect(described_class.for_admin_list.map(&:id)).to eq(
        [earlier_start.id, later_start.id, expired.id, revoked.id]
      )
    end
  end
end
