# frozen_string_literal: true

class SandboxController < AuthenticatedController
  PENDING_CHECKIN_SESSION_KEY = :sandbox_pending_checkin

  skip_before_action :authenticate_user!, if: :token_param_present?
  before_action :reject_invalid_sandbox_token!, if: :token_param_present?
  before_action :require_sandbox_checkin!, only: [:show, :run], if: :token_param_present?

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
    audit_run = start_token_run_audit(source_code, language, input)
    result = nil
    execute_error = nil

    begin
      result = SandboxExecutionService.new(
        source_code: source_code,
        language: language,
        input: input
      ).execute

      render json: { success: true, **result }
    rescue => e
      execute_error = e
      Rails.logger.error "Sandbox run error: #{e.message}"
      render json: { success: false, error: "Server error: #{e.message}" }, status: :internal_server_error
    ensure
      finish_token_run_audit(audit_run, result, execute_error)
    end
  end

  # Identity form shown before the editor on a token URL.
  def checkin
    redirect_to sandbox_token_path(params[:token]) and return if current_sandbox_checkin

    @sandbox_access_token = current_sandbox_access_token
    @checkin = pending_checkin_from_session || @sandbox_access_token.sandbox_access_token_checkins.new
  end

  # Validates form fields and stores them in session for the review page.
  def create_checkin
    redirect_to sandbox_token_path(params[:token]) and return if current_sandbox_checkin

    @sandbox_access_token = current_sandbox_access_token
    @checkin = @sandbox_access_token.sandbox_access_token_checkins.new(checkin_params)
    if @checkin.reviewable?
      store_pending_checkin(@checkin)
      redirect_to sandbox_token_confirm_checkin_path(params[:token])
    else
      @checkin.valid?
      @checkin.errors.delete(:ip_address)
      render :checkin, status: :unprocessable_entity
    end
  end

  # Read-only review of the pending identity. Nothing is written yet.
  def confirm_checkin
    redirect_to sandbox_token_path(params[:token]) and return if current_sandbox_checkin

    pending = pending_checkin_attributes
    if pending.blank?
      redirect_to sandbox_token_checkin_path(params[:token])
      return
    end

    @sandbox_access_token = current_sandbox_access_token
    @checkin = @sandbox_access_token.sandbox_access_token_checkins.new(pending)
  end

  # Persists the check-in (or reuses an existing row), sets the cookie, and opens the editor.
  def complete_checkin
    redirect_to sandbox_token_path(params[:token]) and return if current_sandbox_checkin

    pending = pending_checkin_attributes
    if pending.blank?
      redirect_to sandbox_token_checkin_path(params[:token])
      return
    end

    checkin = persist_checkin!(pending)
    set_sandbox_checkin_cookie(checkin)
    session.delete(PENDING_CHECKIN_SESSION_KEY)
    redirect_to sandbox_token_path(params[:token])
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

  # Blocks the editor and run endpoint until this browser has a valid check-in cookie.
  def require_sandbox_checkin!
    return if current_sandbox_checkin

    if action_name == "show"
      redirect_to sandbox_token_checkin_path(params[:token])
    else
      render json: { success: false, error: "Check-in required" }, status: :forbidden
    end
  end

  def current_sandbox_checkin
    return @current_sandbox_checkin if defined?(@current_sandbox_checkin)

    token = current_sandbox_access_token
    if token.blank?
      @current_sandbox_checkin = nil
      return
    end

    raw_id = cookies.signed[sandbox_checkin_cookie_name]
    @current_sandbox_checkin = if raw_id.present?
                                 token.sandbox_access_token_checkins.find_by(id: raw_id)
                               end
  end

  def sandbox_checkin_cookie_name
    "sandbox_checkin_#{current_sandbox_access_token.id}"
  end

  def set_sandbox_checkin_cookie(checkin)
    token = current_sandbox_access_token
    cookies.signed[sandbox_checkin_cookie_name] = {
      value: checkin.id,
      httponly: true,
      expires: token.expires_at,
      same_site: :lax
    }
  end

  def checkin_params
    params.require(:sandbox_access_token_checkin).permit(:first_name, :last_name, :id_type, :document_number)
  end

  def store_pending_checkin(checkin)
    session[PENDING_CHECKIN_SESSION_KEY] = {
      "token_id" => current_sandbox_access_token.id,
      "first_name" => checkin.first_name,
      "last_name" => checkin.last_name,
      "id_type" => checkin.id_type,
      "document_number" => checkin.document_number
    }
  end

  def pending_checkin_attributes
    data = session[PENDING_CHECKIN_SESSION_KEY]
    return if data.blank?
    return if data["token_id"] != current_sandbox_access_token.id

    data.slice("first_name", "last_name", "id_type", "document_number")
  end

  def pending_checkin_from_session
    attrs = pending_checkin_attributes
    return if attrs.blank?

    current_sandbox_access_token.sandbox_access_token_checkins.new(attrs)
  end

  # Inserts a check-in, or returns the existing row when this identity is already on the token.
  def persist_checkin!(attrs)
    token = current_sandbox_access_token
    token.sandbox_access_token_checkins.find_or_create_by!(
      id_type: attrs["id_type"],
      document_number: attrs["document_number"]
    ) do |row|
      row.first_name = attrs["first_name"]
      row.last_name = attrs["last_name"]
      row.ip_address = request.remote_ip
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    token.sandbox_access_token_checkins.find_by!(
      id_type: attrs["id_type"],
      document_number: attrs["document_number"]
    )
  end

  # Creates a submitted audit row before execute. No-op without a token check-in.
  def start_token_run_audit(source_code, language, input)
    checkin = current_sandbox_checkin
    return if checkin.blank?

    SandboxAccessTokenRun.create!(
      sandbox_access_token: current_sandbox_access_token,
      sandbox_access_token_checkin: checkin,
      programming_language: language,
      source_code: source_code,
      stdin: input,
      status: :submitted
    )
  end

  # Writes the final status after execute. Uses error when execute raised.
  def finish_token_run_audit(audit_run, result, execute_error)
    return if audit_run.blank?

    if execute_error
      audit_run.update!(
        status: :error,
        stderr: execute_error.message,
        finished_at: Time.current
      )
    elsif result
      audit_run.update!(
        status: result[:status],
        stdout: result[:output],
        stderr: result[:error],
        runtime_ms: result[:runtime_ms],
        finished_at: Time.current
      )
    end
  end
end
