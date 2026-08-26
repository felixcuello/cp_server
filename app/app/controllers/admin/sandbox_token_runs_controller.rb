# frozen_string_literal: true

class Admin::SandboxTokenRunsController < AdminController
  before_action :set_sandbox_access_token

  # Lists runs for one class token, newest first.
  def index
    runs = @sandbox_access_token.sandbox_access_token_runs
                                .includes(:sandbox_access_token_checkin, :programming_language)
                                .order(created_at: :desc)

    @page = (params[:page] || 1).to_i
    @per_page = 20
    @total_count = runs.count
    @total_pages = (@total_count / @per_page.to_f).ceil
    @sandbox_access_token_runs = runs.offset((@page - 1) * @per_page).limit(@per_page)
  end

  # Shows source, stdin, and result for one audited run.
  def show
    @sandbox_access_token_run = @sandbox_access_token.sandbox_access_token_runs
                                                     .includes(:sandbox_access_token_checkin, :programming_language)
                                                     .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_sandbox_token_runs_path(@sandbox_access_token), alert: "Run not found."
  end

  private

  # Loads the class token for nested run routes.
  def set_sandbox_access_token
    @sandbox_access_token = SandboxAccessToken.find(params[:sandbox_token_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_sandbox_tokens_path, alert: "Token not found."
  end
end
