# frozen_string_literal: true

class SandboxAccessToken < ApplicationRecord
  TIME_ZONE_NAME = "America/Argentina/Buenos_Aires"

  has_many :sandbox_access_token_languages, dependent: :destroy
  has_many :programming_languages, through: :sandbox_access_token_languages

  validates :token, presence: true, uniqueness: true
  validates :valid_from, presence: true
  validates :expires_at, presence: true
  validate :expires_at_must_be_after_valid_from
  validate :expires_at_must_be_in_the_future
  validate :must_have_at_least_one_language

  before_validation :assign_token, on: :create

  # Non-dead rows first by valid_from, then expired and revoked at the end.
  scope :for_admin_list, lambda {
    now = Time.current
    includes(:programming_languages).order(
      Arel.sql(
        sanitize_sql_array(
          [
            "CASE WHEN revoked_at IS NULL AND expires_at > ? THEN 0 ELSE 1 END ASC",
            now
          ]
        )
      ),
      valid_from: :asc
    )
  }

  # Argentina wall-clock zone used to parse and display token times.
  def self.time_zone
    Time.find_zone!(TIME_ZONE_NAME)
  end

  # Token is usable only inside [valid_from, expires_at) and when not revoked.
  def live?
    revoked_at.nil? &&
      valid_from.present? &&
      expires_at.present? &&
      valid_from <= Time.current &&
      expires_at > Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def expired_by_time?
    expires_at.present? && expires_at <= Time.current
  end

  def upcoming?
    !revoked? && !expired_by_time? && valid_from.present? && valid_from > Time.current
  end

  # Expire is allowed on upcoming and live tokens, not on already-dead rows.
  def expirable?
    !revoked? && !expired_by_time?
  end

  # Sets revoked_at so the link 404s on the next request. No-op if already revoked.
  def expire!
    return self if revoked?

    update!(revoked_at: Time.current)
    self
  end

  def valid_from_in_argentina
    valid_from&.in_time_zone(self.class.time_zone)
  end

  def expires_at_in_argentina
    expires_at&.in_time_zone(self.class.time_zone)
  end

  def status_label
    return "revoked" if revoked?
    return "expired" if expired_by_time?
    return "upcoming" if upcoming?

    "live"
  end

  # Comma-separated language names for the admin list.
  def language_names
    programming_languages.sort_by(&:name).map(&:name).join(", ")
  end

  def allows_language?(language)
    programming_languages.exists?(id: language.id)
  end

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(24).delete("=")
  end

  def expires_at_must_be_after_valid_from
    return if valid_from.blank? || expires_at.blank?
    return if expires_at > valid_from

    errors.add(:expires_at, "must be after valid from")
  end

  def expires_at_must_be_in_the_future
    return if expires_at.blank?
    return if expires_at > Time.current

    errors.add(:expires_at, "must be in the future")
  end

  def must_have_at_least_one_language
    return if programming_languages.any?

    errors.add(:programming_languages, "must include at least one language")
  end
end
