# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin sandbox tokens", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:language) { create(:programming_language) }

  describe "authentication" do
    it "redirects non-admins away from the index" do
      sign_in user

      get admin_sandbox_tokens_path

      expect(response).to redirect_to(home_path)
    end

    it "requires login" do
      get admin_sandbox_tokens_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /admin/sandbox_tokens" do
    it "lists tokens by valid_from with expired last" do
      sign_in admin
      later = create(:sandbox_access_token, :upcoming, label: "Later", valid_from: 2.days.from_now, expires_at: 9.days.from_now)
      earlier = create(:sandbox_access_token, label: "Next class", valid_from: 1.hour.ago, expires_at: 3.hours.from_now)
      create(:sandbox_access_token, :expired, label: "Old")

      get admin_sandbox_tokens_path

      expect(response).to have_http_status(:success)
      expect(response.body.index("Next class")).to be < response.body.index("Later")
      expect(response.body.index("Later")).to be < response.body.index("Old")
      expect(response.body).to include(sandbox_token_url(earlier.token))
      expect(response.body).to include(sandbox_token_url(later.token))
      expect(response.body).to include("Languages")
      expect(response.body).to include(earlier.language_names)
      expect(response.body).to include("Edit")
    end
  end

  describe "POST /admin/sandbox_tokens" do
    it "creates a token using Argentina wall-clock time" do
      sign_in admin
      argentina = SandboxAccessToken.time_zone

      travel_to argentina.local(2026, 8, 24, 12, 0, 0) do
        post admin_sandbox_tokens_path, params: {
          sandbox_access_token: {
            label: "Clase 24/08",
            valid_from: "2026-08-24T10:00",
            expires_at: "2026-08-24T23:00",
            programming_language_ids: [language.id]
          }
        }

        token = SandboxAccessToken.last
        expect(response).to redirect_to(admin_sandbox_tokens_path)
        expect(token.label).to eq("Clase 24/08")
        expect(token.valid_from_in_argentina.strftime("%Y-%m-%d %H:%M")).to eq("2026-08-24 10:00")
        expect(token.expires_at_in_argentina.strftime("%Y-%m-%d %H:%M")).to eq("2026-08-24 23:00")
        expect(token.live?).to be(true)
        expect(token.programming_languages).to contain_exactly(language)
      end
    end

    it "rejects a token with no languages" do
      sign_in admin

      post admin_sandbox_tokens_path, params: {
        sandbox_access_token: {
          label: "No langs",
          valid_from: 1.hour.from_now.strftime("%Y-%m-%dT%H:%M"),
          expires_at: 2.hours.from_now.strftime("%Y-%m-%dT%H:%M")
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(SandboxAccessToken.count).to eq(0)
    end
  end

  describe "GET /admin/sandbox_tokens/:id/edit" do
    it "renders the edit form for a live token" do
      sign_in admin
      token = create(:sandbox_access_token, programming_languages: [language])

      get edit_admin_sandbox_token_path(token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit sandbox token")
      expect(response.body).to include("Save token")
    end

    it "redirects away from an expired token" do
      sign_in admin
      token = create(:sandbox_access_token, :expired)

      get edit_admin_sandbox_token_path(token)

      expect(response).to redirect_to(admin_sandbox_tokens_path)
    end
  end

  describe "PATCH /admin/sandbox_tokens/:id" do
    it "extends expiry and changes languages on a live token" do
      sign_in admin
      argentina = SandboxAccessToken.time_zone
      extra = create(:programming_language, name: "C89")

      travel_to argentina.local(2026, 8, 24, 12, 0, 0) do
        token = create(:sandbox_access_token, programming_languages: [language],
                       valid_from: 1.hour.ago, expires_at: 3.hours.from_now)

        patch admin_sandbox_token_path(token), params: {
          sandbox_access_token: {
            label: token.label,
            valid_from: "2026-08-24T11:00",
            expires_at: "2026-08-24T23:30",
            programming_language_ids: [language.id, extra.id]
          }
        }

        token.reload
        expect(response).to redirect_to(admin_sandbox_tokens_path)
        expect(token.expires_at_in_argentina.strftime("%Y-%m-%d %H:%M")).to eq("2026-08-24 23:30")
        expect(token.programming_languages).to contain_exactly(language, extra)
      end
    end

    it "does not update an expired token" do
      sign_in admin
      token = create(:sandbox_access_token, :expired)
      original_expiry = token.expires_at

      patch admin_sandbox_token_path(token), params: {
        sandbox_access_token: {
          label: "Nope",
          valid_from: 1.hour.ago.strftime("%Y-%m-%dT%H:%M"),
          expires_at: 2.hours.from_now.strftime("%Y-%m-%dT%H:%M"),
          programming_language_ids: [language.id]
        }
      }

      expect(response).to redirect_to(admin_sandbox_tokens_path)
      expect(token.reload.expires_at).to eq(original_expiry)
    end
  end

  describe "POST /admin/sandbox_tokens/:id/expire" do
    it "revokes an upcoming token" do
      sign_in admin
      token = create(:sandbox_access_token, :upcoming)

      post expire_admin_sandbox_token_path(token)

      expect(response).to redirect_to(admin_sandbox_tokens_path)
      expect(token.reload.live?).to be(false)
      expect(token.revoked?).to be(true)
    end

    it "revokes a live token" do
      sign_in admin
      token = create(:sandbox_access_token)

      post expire_admin_sandbox_token_path(token)

      expect(response).to redirect_to(admin_sandbox_tokens_path)
      expect(token.reload.revoked?).to be(true)
    end
  end
end
