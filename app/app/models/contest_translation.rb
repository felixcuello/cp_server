# frozen_string_literal: true

class ContestTranslation < ApplicationRecord
  belongs_to :contest

  validates :locale, presence: true, inclusion: { in: %w[en es] }
  validates :name, presence: true
  validates :locale, uniqueness: { scope: :contest_id }
end
