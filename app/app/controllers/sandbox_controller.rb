# frozen_string_literal: true

class SandboxController < AuthenticatedController
  def show
    @languages = ProgrammingLanguage.all
  end

  def run
    language = ProgrammingLanguage.find_by(id: params[:programming_language_id])
    unless language
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
end
