# frozen_string_literal: true

class ConstraintTranslation < ApplicationRecord
  belongs_to :constraint

  validates :locale, presence: true, inclusion: { in: %w[en es] }
  validates :description, presence: true
  validates :locale, uniqueness: { scope: :constraint_id }
end
