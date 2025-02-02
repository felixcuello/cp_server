# frozen_string_literal: true

class ProgrammingLanguage < ApplicationRecord
  validates :name, presence: true
  validates :memory_limit_kb, numericality: { greater_than: 0 }
  validates :time_limit_sec, numericality: { greater_than: 0 }
  validates :extension, presence: true
end
