# frozen_string_literal: true

class SandboxController < AuthenticatedController
  skip_before_action :authenticate_user!, if: :token_param_present?
  before_action :reject_invalid_sandbox_token!, if: :token_param_present?

  def show
    @sandbox_access_token = current_sandbox_access_token
    @languages = languages_for_sandbox
  end

  def run
    language = ProgrammingLanguage.find_by(id: params[:programming_language_id])
    unless language && language_allowed?(language)
      render json: { success: false, error: "Invalid language" }, status: :unprocessable_entity
      return
    end

    source_code = if params[:source_code].respond_to?(:read)
                    params[:source_code].read
                  else
                    params[:source_code].to_s
                  end

    if source_code.blank?
      render json: { success: false, error: "No source code provided" }, status: :unprocessable_entity
      return
    end

    input = params[:input].to_s

    result = SandboxExecutionService.new(
      source_code: source_code,
      language: language,
      input: input
    ).execute

    render json: { success: true, **result }
  rescue => e
    Rails.logger.error "Sandbox run error: #{e.message}"
    render json: { success: false, error: "Server error: #{e.message}" }, status: :internal_server_error
  end

  private

  def token_param_present?
    params[:token].present?
  end

  def current_sandbox_access_token
    return @found_sandbox_access_token if defined?(@found_sandbox_access_token)

    @found_sandbox_access_token = SandboxAccessToken.find_by(token: params[:token])
  end

  def languages_for_sandbox
    token = current_sandbox_access_token
    if token
      token.programming_languages.by_name
    else
      ProgrammingLanguage.by_name
    end
  end

  def language_allowed?(language)
    token = current_sandbox_access_token
    return true unless token

    token.allows_language?(language)
  end

  # Renders the bilingual 404 for unknown, expired, or revoked tokens. Must not run code.
  def reject_invalid_sandbox_token!
    token = current_sandbox_access_token
    return if token&.live?

    render "sandbox/invalid_token", status: :not_found
  end
end
