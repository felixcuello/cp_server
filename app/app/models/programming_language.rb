# frozen_string_literal: true

class ProgrammingLanguage < ApplicationRecord
  has_many :sandbox_access_token_languages, dependent: :destroy
  has_many :sandbox_access_tokens, through: :sandbox_access_token_languages

  scope :by_name, -> { order(:name) }

  validates :name, presence: true
  validates :memory_limit_kb, numericality: { greater_than: 0 }
  validates :time_limit_sec, numericality: { greater_than: 0 }
  validates :extension, presence: true
end
