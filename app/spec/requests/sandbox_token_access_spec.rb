# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sandbox token access", type: :request do
  let(:language) { create(:programming_language) }
  let(:execution_result) do
    { status: "success", output: "hello", error: nil, runtime_ms: 12 }
  end

  def stub_sandbox_execution
    service = instance_double(SandboxExecutionService, execute: execution_result)
    allow(SandboxExecutionService).to receive(:new).and_return(service)
    service
  end

  def complete_sandbox_checkin(token, attrs = {})
    payload = {
      first_name: "Ana",
      last_name: "Perez",
      id_type: "dni",
      document_number: "12345678"
    }.merge(attrs)

    post sandbox_token_checkin_path(token.token), params: {
      sandbox_access_token_checkin: payload
    }
    post sandbox_token_confirm_checkin_path(token.token)
  end

  describe "GET /sandbox" do
    it "requires login when no token is present" do
      get sandbox_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "does not show a token countdown for a logged-in user" do
      sign_in create(:user)

      get sandbox_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("sandbox-token-countdown")
    end

    it "lists every language including ones not attached to a token" do
      sign_in create(:user)
      allowed = create(:programming_language, name: "AllowedLang")
      blocked = create(:programming_language, name: "BlockedLang")
      create(:sandbox_access_token, programming_languages: [allowed])

      get sandbox_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("AllowedLang")
      expect(response.body).to include("BlockedLang")
    end

    it "keeps app navigation for a logged-in user" do
      sign_in create(:user)

      get sandbox_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(problems_path)
      expect(response.body).to include("navbar-desktop-links")
    end
  end

  describe "GET /sandbox/:token" do
    it "redirects a live token without a check-in cookie to the identity form" do
      token = create(:sandbox_access_token)

      get sandbox_token_path(token.token)

      expect(response).to redirect_to(sandbox_token_checkin_path(token.token))
      follow_redirect!
      expect(response.body).to include("Identify yourself")
      expect(response.body).not_to include("sandbox-token-countdown")
      expect(response.body).not_to include("sandbox-container")
    end

    it "renders the sandbox for a live token after check-in without login" do
      token = create(:sandbox_access_token)
      complete_sandbox_checkin(token)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("This token is not valid.")
      expect(response.body).to include("sandbox-token-countdown")
      expect(response.body).to include("Time remaining")
    end

    it "keeps the sandbox after the original expiry when expires_at was extended" do
      original_expiry = 10.minutes.from_now
      token = create(:sandbox_access_token, valid_from: 1.hour.ago, expires_at: original_expiry)
      token.update!(expires_at: 2.hours.from_now)
      complete_sandbox_checkin(token)

      travel_to original_expiry + 1.minute do
        get sandbox_token_path(token.token)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("sandbox-token-countdown")
        expect(response.body).not_to include("This token is not valid.")
      end
    end

    it "lists only languages allowed on the token" do
      allowed = create(:programming_language, name: "AllowedLang")
      create(:programming_language, name: "BlockedLang")
      token = create(:sandbox_access_token, programming_languages: [allowed])
      complete_sandbox_checkin(token)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("AllowedLang")
      expect(response.body).not_to include("BlockedLang")
    end

    it "hides app navigation even when the visitor is signed in" do
      sign_in create(:user, :admin)
      token = create(:sandbox_access_token)
      complete_sandbox_checkin(token)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("navbar-desktop-links")
      expect(response.body).not_to include(">#{I18n.t('navigation.problems')}<")
      expect(response.body).not_to include("Sandbox tokens")
    end

    it "still requires check-in when the visitor is signed in" do
      sign_in create(:user)
      token = create(:sandbox_access_token)

      get sandbox_token_path(token.token)

      expect(response).to redirect_to(sandbox_token_checkin_path(token.token))
    end

    it "returns the bilingual 404 for an upcoming token" do
      token = create(:sandbox_access_token, :upcoming)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("This token is not valid.")
      expect(response.body).to include("Este token no es válido.")
    end

    it "returns the bilingual 404 for an expired token" do
      token = create(:sandbox_access_token, :expired)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("This token is not valid.")
      expect(response.body).to include("Este token no es válido.")
    end

    it "returns the bilingual 404 for a revoked token" do
      token = create(:sandbox_access_token, :revoked)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("This token is not valid.")
    end

    it "returns the bilingual 404 for an unknown token" do
      get sandbox_token_path("a" * 32)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("This token is not valid.")
    end
  end

  describe "POST /sandbox/run" do
    it "requires login when no token is present" do
      post sandbox_run_path, params: {
        programming_language_id: language.id,
        source_code: "puts 1",
        input: ""
      }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "executes any language for a logged-in user" do
      sign_in create(:user)
      allowed = create(:programming_language, name: "AllowedLang")
      blocked = create(:programming_language, name: "BlockedLang")
      create(:sandbox_access_token, programming_languages: [allowed])
      stub_sandbox_execution

      expect {
        post sandbox_run_path, params: {
          programming_language_id: blocked.id,
          source_code: "puts 1",
          input: ""
        }
      }.not_to change(SandboxAccessTokenRun, :count)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["success"]).to eq(true)
      expect(SandboxExecutionService).to have_received(:new)
    end
  end

  describe "POST /sandbox/:token/run" do
    it "does not execute without a check-in cookie" do
      token = create(:sandbox_access_token, programming_languages: [language])
      allow(SandboxExecutionService).to receive(:new)

      expect {
        post sandbox_token_run_path(token.token), params: {
          programming_language_id: language.id,
          source_code: "puts 1",
          input: ""
        }
      }.not_to change(SandboxAccessTokenRun, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["success"]).to eq(false)
      expect(SandboxExecutionService).not_to have_received(:new)
    end

    it "executes for a live token after check-in without login" do
      token = create(:sandbox_access_token, programming_languages: [language])
      complete_sandbox_checkin(token)
      stub_sandbox_execution

      post sandbox_token_run_path(token.token), params: {
        programming_language_id: language.id,
        source_code: "puts 1",
        input: ""
      }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["success"]).to eq(true)
      expect(SandboxExecutionService).to have_received(:new)
    end

    it "stores source, stdin, and the result for a token check-in run" do
      token = create(:sandbox_access_token, programming_languages: [language])
      complete_sandbox_checkin(token)
      stub_sandbox_execution

      expect {
        post sandbox_token_run_path(token.token), params: {
          programming_language_id: language.id,
          source_code: "puts 1",
          input: "hello"
        }
      }.to change(SandboxAccessTokenRun, :count).by(1)

      run = SandboxAccessTokenRun.last
      expect(run.sandbox_access_token).to eq(token)
      expect(run.source_code).to eq("puts 1")
      expect(run.stdin).to eq("hello")
      expect(run.stdout).to eq("hello")
      expect(run.status).to eq("success")
      expect(run.runtime_ms).to eq(12)
      expect(run.finished_at).to be_present
    end

    it "marks the audit row as error when execute raises" do
      token = create(:sandbox_access_token, programming_languages: [language])
      complete_sandbox_checkin(token)
      service = instance_double(SandboxExecutionService)
      allow(SandboxExecutionService).to receive(:new).and_return(service)
      allow(service).to receive(:execute).and_raise(StandardError, "boom")

      expect {
        post sandbox_token_run_path(token.token), params: {
          programming_language_id: language.id,
          source_code: "puts 1",
          input: ""
        }
      }.to change(SandboxAccessTokenRun, :count).by(1)

      run = SandboxAccessTokenRun.last
      expect(run.status).to eq("error")
      expect(run.stderr).to eq("boom")
      expect(run.finished_at).to be_present
      expect(response).to have_http_status(:internal_server_error)
    end

    it "does not create a run for blank source" do
      token = create(:sandbox_access_token, programming_languages: [language])
      complete_sandbox_checkin(token)
      allow(SandboxExecutionService).to receive(:new)

      expect {
        post sandbox_token_run_path(token.token), params: {
          programming_language_id: language.id,
          source_code: "",
          input: ""
        }
      }.not_to change(SandboxAccessTokenRun, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "does not execute a language that is not on the token" do
      allowed = create(:programming_language, name: "AllowedLang")
      blocked = create(:programming_language, name: "BlockedLang")
      token = create(:sandbox_access_token, programming_languages: [allowed])
      complete_sandbox_checkin(token)
      allow(SandboxExecutionService).to receive(:new)

      expect {
        post sandbox_token_run_path(token.token), params: {
          programming_language_id: blocked.id,
          source_code: "puts 1",
          input: ""
        }
      }.not_to change(SandboxAccessTokenRun, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["success"]).to eq(false)
      expect(SandboxExecutionService).not_to have_received(:new)
    end

    it "does not execute for an upcoming token" do
      token = create(:sandbox_access_token, :upcoming)
      allow(SandboxExecutionService).to receive(:new)

      post sandbox_token_run_path(token.token), params: {
        programming_language_id: language.id,
        source_code: "puts 1",
        input: ""
      }

      expect(response).to have_http_status(:not_found)
      expect(SandboxExecutionService).not_to have_received(:new)
    end

    it "does not execute for an expired token" do
      token = create(:sandbox_access_token, :expired)
      allow(SandboxExecutionService).to receive(:new)

      post sandbox_token_run_path(token.token), params: {
        programming_language_id: language.id,
        source_code: "puts 1",
        input: ""
      }

      expect(response).to have_http_status(:not_found)
      expect(SandboxExecutionService).not_to have_received(:new)
    end

    it "does not execute for a revoked token" do
      token = create(:sandbox_access_token, :revoked)
      allow(SandboxExecutionService).to receive(:new)

      post sandbox_token_run_path(token.token), params: {
        programming_language_id: language.id,
        source_code: "puts 1",
        input: ""
      }

      expect(response).to have_http_status(:not_found)
      expect(SandboxExecutionService).not_to have_received(:new)
    end

    it "does not execute for an unknown token" do
      allow(SandboxExecutionService).to receive(:new)

      post sandbox_token_run_path("b" * 32), params: {
        programming_language_id: language.id,
        source_code: "puts 1",
        input: ""
      }

      expect(response).to have_http_status(:not_found)
      expect(SandboxExecutionService).not_to have_received(:new)
    end
  end

  describe "sandbox token check-in" do
    let(:checkin_params) do
      {
        first_name: "Ana",
        last_name: "Perez",
        id_type: "dni",
        document_number: "12.345.678"
      }
    end

    it "does not insert a row when submitting the form" do
      token = create(:sandbox_access_token)

      expect {
        post sandbox_token_checkin_path(token.token), params: {
          sandbox_access_token_checkin: checkin_params
        }
      }.not_to change(SandboxAccessTokenCheckin, :count)

      expect(response).to redirect_to(sandbox_token_confirm_checkin_path(token.token))
      follow_redirect!
      expect(response.body).to include("Confirm your details")
      expect(response.body).to include("Ana")
      expect(response.body).to include("12345678")
    end

    it "inserts a row with IP and sets a cookie on confirm" do
      token = create(:sandbox_access_token)

      post sandbox_token_checkin_path(token.token), params: {
        sandbox_access_token_checkin: checkin_params
      }

      expect {
        post sandbox_token_confirm_checkin_path(token.token)
      }.to change(SandboxAccessTokenCheckin, :count).by(1)

      checkin = SandboxAccessTokenCheckin.last
      expect(checkin.first_name).to eq("Ana")
      expect(checkin.last_name).to eq("Perez")
      expect(checkin.id_type).to eq("dni")
      expect(checkin.document_number).to eq("12345678")
      expect(checkin.ip_address).to be_present
      expect(checkin.sandbox_access_token).to eq(token)
      expect(response).to redirect_to(sandbox_token_path(token.token))

      follow_redirect!
      expect(response.body).to include("sandbox-token-countdown")
    end

    it "reuses an existing row for the same identity on the same token" do
      token = create(:sandbox_access_token)
      existing = create(
        :sandbox_access_token_checkin,
        sandbox_access_token: token,
        id_type: :dni,
        document_number: "12345678",
        first_name: "Ana"
      )

      expect {
        complete_sandbox_checkin(token, document_number: "12345678")
      }.not_to change(SandboxAccessTokenCheckin, :count)

      expect(response).to redirect_to(sandbox_token_path(token.token))
      follow_redirect!
      expect(response.body).to include("sandbox-token-countdown")
      expect(SandboxAccessTokenCheckin.last).to eq(existing)
    end

    it "returns 404 for check-in on an expired token" do
      token = create(:sandbox_access_token, :expired)

      get sandbox_token_checkin_path(token.token)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("This token is not valid.")
    end

    it "redirects confirm back to the form when there is no pending identity" do
      token = create(:sandbox_access_token)

      get sandbox_token_confirm_checkin_path(token.token)

      expect(response).to redirect_to(sandbox_token_checkin_path(token.token))
    end
  end
end
