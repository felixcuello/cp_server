# frozen_string_literal: true

FactoryBot.define do
  factory :sandbox_access_token_run do
    sandbox_access_token
    sandbox_access_token_checkin do
      association :sandbox_access_token_checkin, sandbox_access_token: sandbox_access_token
    end
    programming_language
    source_code { "puts 1" }
    stdin { "" }
    status { :submitted }
  end
end
