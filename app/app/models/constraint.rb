# frozen_string_literal: true

class Constraint < ApplicationRecord
  belongs_to :problem
  has_many :translations, class_name: 'ConstraintTranslation', dependent: :destroy

  validates :description, presence: true
  validates :sort_order, presence: true

  # Get translated description for the current locale
  def translated_description(locale = I18n.locale)
    translation = translation_for(locale)
    translation&.description || description
  end

  private

  # Find translation for a specific locale, with fallback to English
  def translation_for(locale)
    translations.find_by(locale: locale) || translations.find_by(locale: :en)
  end
end
