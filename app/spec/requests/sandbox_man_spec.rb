# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sandbox man pages", type: :request do
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

  describe "GET /sandbox/man/index" do
    it "requires login when no token is present" do
      get sandbox_man_index_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns pages and topics for a logged-in user" do
      sign_in create(:user)

      get sandbox_man_index_path

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      names = body["pages"].map { |page| page["name"] }
      expect(names).to include("pthread_create")
      expect(body["topics"]).to be_an(Array)
      expect(body["topics"].first).to include("key", "label", "pages")
    end
  end

  describe "GET /sandbox/man/:section/:page" do
    it "returns sanitized HTML for a logged-in user" do
      sign_in create(:user)

      get sandbox_man_page_path(section: "3", page: "pthread_create")

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["missing"]).to eq(false)
      expect(body["fallback"]).to eq(false)
      expect(body["html"]).to include("pthread_create")
      expect(body["html"]).to include('data-man-name="pthread_join"')
      expect(body["html"]).to include('data-man-section="3"')
      expect(body["html"]).to include('data-man-name="fork"')
    end

    it "falls back to English when the locale page is absent" do
      sign_in create(:user)

      get sandbox_man_page_path(section: "3", page: "pthread_create"), params: { locale: "es" }

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["missing"]).to eq(false)
      expect(body["fallback"]).to eq(true)
      expect(body["html"]).to include("pthread_create")
    end

    it "returns missing: true for an unknown page name" do
      sign_in create(:user)

      get sandbox_man_page_path(section: "3", page: "no_such_function")

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["missing"]).to eq(true)
      expect(body["name"]).to eq("no_such_function")
      expect(body["section"]).to eq("3")
    end

    it "rejects a bad section" do
      sign_in create(:user)

      get sandbox_man_page_path(section: "99", page: "fork")

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a path traversal page name" do
      sign_in create(:user)

      get sandbox_man_page_path(section: "3", page: "pthread..create")

      # Rack can reject traversal-shaped paths before Rails reaches the action.
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /sandbox/:token/man" do
    it "forbids the index without a check-in cookie" do
      token = create(:sandbox_access_token)

      get sandbox_token_man_index_path(token.token)

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Check-in required")
    end

    it "returns a page after check-in without login" do
      token = create(:sandbox_access_token)
      complete_sandbox_checkin(token)

      get sandbox_token_man_page_path(token: token.token, section: "3", page: "pthread_create")

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["missing"]).to eq(false)
      expect(body["html"]).to include("create a new thread")
    end
  end

  describe "GET /sandbox" do
    it "includes the man button markup" do
      sign_in create(:user)

      get sandbox_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("click->sandbox#toggleMan")
      expect(response.body).to include("sandbox-docs-pane")
    end
  end
end
