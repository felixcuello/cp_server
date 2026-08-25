# frozen_string_literal: true

class Admin::SandboxTokensController < AdminController
  before_action :load_programming_languages, only: [:new, :create, :edit, :update]
  before_action :set_editable_token, only: [:edit, :update]

  def index
    @sandbox_access_tokens = SandboxAccessToken.for_admin_list
  end

  def new
    @sandbox_access_token = SandboxAccessToken.new
  end

  def create
    @sandbox_access_token = SandboxAccessToken.new
    assign_token_attributes(@sandbox_access_token)

    if @sandbox_access_token.save
      redirect_to admin_sandbox_tokens_path,
                  notice: "Token created. URL: #{sandbox_token_url(@sandbox_access_token.token)}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    assign_token_attributes(@sandbox_access_token)

    if @sandbox_access_token.save
      redirect_to admin_sandbox_tokens_path, notice: "Token updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def expire
    token = SandboxAccessToken.find(params[:id])

    unless token.expirable?
      redirect_to admin_sandbox_tokens_path, alert: "Token is already expired."
      return
    end

    token.expire!
    redirect_to admin_sandbox_tokens_path, notice: "Token expired."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_sandbox_tokens_path, alert: "Token not found."
  end

  private

  def token_params
    params.require(:sandbox_access_token).permit(:label, :valid_from, :expires_at, programming_language_ids: [])
  end

  def load_programming_languages
    @programming_languages = ProgrammingLanguage.by_name
  end

  def set_editable_token
    @sandbox_access_token = SandboxAccessToken.find(params[:id])
    return if @sandbox_access_token.expirable?

    redirect_to admin_sandbox_tokens_path, alert: "Expired tokens cannot be edited."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_sandbox_tokens_path, alert: "Token not found."
  end

  def assign_token_attributes(token)
    token.label = token_params[:label]
    token.valid_from = parse_argentina_datetime(token_params[:valid_from])
    token.expires_at = parse_argentina_datetime(token_params[:expires_at])
    token.programming_language_ids = Array(token_params[:programming_language_ids]).reject(&:blank?)
  end

  # Interprets a datetime-local value as Argentina wall-clock time, then stores UTC.
  def parse_argentina_datetime(raw_value)
    return if raw_value.blank?

    SandboxAccessToken.time_zone.parse(raw_value)
  end
end
