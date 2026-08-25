# frozen_string_literal: true

class SandboxAccessTokenLanguage < ApplicationRecord
  belongs_to :sandbox_access_token
  belongs_to :programming_language

  validates :programming_language_id, uniqueness: { scope: :sandbox_access_token_id }
end
