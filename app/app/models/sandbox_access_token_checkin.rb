# frozen_string_literal: true

class SandboxAccessTokenCheckin < ApplicationRecord
  belongs_to :sandbox_access_token

  enum :id_type, {
    dni: 0,
    pasaporte: 1,
    legajo: 2
  }

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :id_type, presence: true
  validates :document_number, presence: true
  validates :ip_address, presence: true
  validates :document_number, uniqueness: { scope: [:sandbox_access_token_id, :id_type] }

  before_validation :normalize_document_number

  # Strips spaces, dots, and dashes so formatted IDs collapse to one value.
  def self.normalized_document_number(value)
    value.to_s.strip.delete(".-")
  end

  # True when the identity form fields are present after normalization.
  def reviewable?
    normalize_document_number
    first_name.present? && last_name.present? && id_type.present? && document_number.present?
  end

  private

  def normalize_document_number
    return if document_number.nil?

    self.document_number = self.class.normalized_document_number(document_number)
  end
end
