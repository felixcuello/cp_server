# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin sandbox token runs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:token) { create(:sandbox_access_token) }

  describe "authentication" do
    it "redirects non-admins away from the run list" do
      sign_in user

      get admin_sandbox_token_runs_path(token)

      expect(response).to redirect_to(home_path)
    end

    it "requires login" do
      get admin_sandbox_token_runs_path(token)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /admin/sandbox_tokens/:sandbox_token_id/runs" do
    it "lists that token's runs newest first" do
      sign_in admin
      other_token = create(:sandbox_access_token)
      older_checkin = create(:sandbox_access_token_checkin, sandbox_access_token: token, first_name: "Older", document_number: "11111111")
      newer_checkin = create(:sandbox_access_token_checkin, sandbox_access_token: token, first_name: "Newer", document_number: "22222222")
      create(:sandbox_access_token_run, sandbox_access_token: token, sandbox_access_token_checkin: older_checkin)
      newer = create(
        :sandbox_access_token_run,
        sandbox_access_token: token,
        sandbox_access_token_checkin: newer_checkin,
        created_at: 1.minute.from_now
      )
      create(
        :sandbox_access_token_run,
        sandbox_access_token: other_token,
        sandbox_access_token_checkin: create(
          :sandbox_access_token_checkin,
          sandbox_access_token: other_token,
          first_name: "Other",
          document_number: "99999999"
        )
      )

      get admin_sandbox_token_runs_path(token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Submissions")
      expect(response.body).to include("Older")
      expect(response.body).to include("Newer")
      expect(response.body).to include("11111111")
      expect(response.body).to include("22222222")
      expect(response.body.index("Newer")).to be < response.body.index("Older")
      expect(response.body).to include(admin_sandbox_token_run_path(token, newer))
      expect(response.body).not_to include("99999999")
    end
  end

  describe "GET /admin/sandbox_tokens/:sandbox_token_id/runs/:id" do
    it "shows source and stdin" do
      sign_in admin
      run = create(
        :sandbox_access_token_run,
        sandbox_access_token: token,
        source_code: "puts 42",
        stdin: "input-data",
        stdout: "42",
        status: :success
      )

      get admin_sandbox_token_run_path(token, run)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("puts 42")
      expect(response.body).to include("input-data")
      expect(response.body).to include("42")
    end

    it "does not show a run from another token" do
      sign_in admin
      other = create(:sandbox_access_token_run)

      get admin_sandbox_token_run_path(token, other)

      expect(response).to redirect_to(admin_sandbox_token_runs_path(token))
    end
  end
end
