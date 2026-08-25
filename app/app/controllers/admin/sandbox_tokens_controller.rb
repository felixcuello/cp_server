# frozen_string_literal: true

class Admin::SandboxTokensController < AdminController
  def index
    @sandbox_access_tokens = SandboxAccessToken.for_admin_list
  end

  def new
    @sandbox_access_token = SandboxAccessToken.new
  end

  def create
    @sandbox_access_token = SandboxAccessToken.new(label: token_params[:label])
    @sandbox_access_token.valid_from = parse_argentina_datetime(token_params[:valid_from])
    @sandbox_access_token.expires_at = parse_argentina_datetime(token_params[:expires_at])

    if @sandbox_access_token.save
      redirect_to admin_sandbox_tokens_path,
                  notice: "Token created. URL: #{sandbox_token_url(@sandbox_access_token.token)}"
    else
      render :new, status: :unprocessable_entity
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
    params.require(:sandbox_access_token).permit(:label, :valid_from, :expires_at)
  end

  # Interprets a datetime-local value as Argentina wall-clock time, then stores UTC.
  def parse_argentina_datetime(raw_value)
    return if raw_value.blank?

    SandboxAccessToken.time_zone.parse(raw_value)
  end
end
