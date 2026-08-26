# frozen_string_literal: true

class SandboxAccessTokenRun < ApplicationRecord
  STATUSES = %w[
    submitted
    success
    compilation_error
    time_limit_exceeded
    memory_limit_exceeded
    runtime_error
    error
  ].freeze

  belongs_to :sandbox_access_token
  belongs_to :sandbox_access_token_checkin
  belongs_to :programming_language

  enum :status, {
    submitted: "submitted",
    success: "success",
    compilation_error: "compilation_error",
    time_limit_exceeded: "time_limit_exceeded",
    memory_limit_exceeded: "memory_limit_exceeded",
    runtime_error: "runtime_error",
    error: "error"
  }, default: :submitted

  validates :source_code, presence: true
  validates :stdin, presence: true, allow_blank: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :checkin_must_belong_to_token

  before_validation :normalize_stdin

  # Argentina wall-clock time for the admin list.
  def created_at_in_argentina
    created_at&.in_time_zone(SandboxAccessToken.time_zone)
  end

  # Argentina wall-clock time for when execution finished.
  def finished_at_in_argentina
    finished_at&.in_time_zone(SandboxAccessToken.time_zone)
  end

  private

  def normalize_stdin
    self.stdin = "" if stdin.nil?
  end

  def checkin_must_belong_to_token
    return if sandbox_access_token_checkin.blank? || sandbox_access_token_id.blank?
    return if sandbox_access_token_checkin.sandbox_access_token_id == sandbox_access_token_id

    errors.add(:sandbox_access_token_checkin, "must belong to the token")
  end
end
