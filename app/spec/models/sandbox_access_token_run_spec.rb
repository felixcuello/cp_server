# frozen_string_literal: true

require "rails_helper"

RSpec.describe SandboxAccessTokenRun, type: :model do
  describe "validations" do
    it "accepts a run that belongs to the check-in's token" do
      run = build(:sandbox_access_token_run)

      expect(run).to be_valid
    end

    it "requires source_code" do
      run = build(:sandbox_access_token_run, source_code: "")

      expect(run).not_to be_valid
      expect(run.errors[:source_code]).to be_present
    end

    it "rejects a check-in from a different token" do
      token = create(:sandbox_access_token)
      other_token = create(:sandbox_access_token)
      checkin = create(:sandbox_access_token_checkin, sandbox_access_token: other_token)
      run = build(:sandbox_access_token_run, sandbox_access_token: token, sandbox_access_token_checkin: checkin)

      expect(run).not_to be_valid
      expect(run.errors[:sandbox_access_token_checkin]).to include("must belong to the token")
    end

    it "defaults status to submitted" do
      run = create(:sandbox_access_token_run)

      expect(run.status).to eq("submitted")
    end

    it "accepts the sandbox execution statuses" do
      expect(described_class.statuses.keys).to match_array(described_class::STATUSES)
    end
  end

  describe "associations" do
    it "belongs to token, checkin, and language" do
      run = create(:sandbox_access_token_run)

      expect(run.sandbox_access_token).to be_present
      expect(run.sandbox_access_token_checkin).to be_present
      expect(run.programming_language).to be_present
      expect(run.sandbox_access_token_checkin.sandbox_access_token).to eq(run.sandbox_access_token)
    end
  end
end
