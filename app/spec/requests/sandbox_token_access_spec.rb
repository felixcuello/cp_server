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

    it "keeps app navigation for a logged-in user" do
      sign_in create(:user)

      get sandbox_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(problems_path)
      expect(response.body).to include("navbar-desktop-links")
    end
  end

  describe "GET /sandbox/:token" do
    it "renders the sandbox for a live token without login" do
      token = create(:sandbox_access_token)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("This token is not valid.")
      expect(response.body).to include("sandbox-token-countdown")
      expect(response.body).to include("Time remaining")
    end

    it "hides app navigation even when the visitor is signed in" do
      sign_in create(:user, :admin)
      token = create(:sandbox_access_token)

      get sandbox_token_path(token.token)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("navbar-desktop-links")
      expect(response.body).not_to include(">#{I18n.t('navigation.problems')}<")
      expect(response.body).not_to include("Sandbox tokens")
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
  end

  describe "POST /sandbox/:token/run" do
    it "executes for a live token without login" do
      token = create(:sandbox_access_token)
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
end
