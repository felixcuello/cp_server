# frozen_string_literal: true

FactoryBot.define do
  factory :submission do
    source_code { "puts 'Hello, World!'" }
    status { "enqueued" }
    problem
    programming_language
    user
  end
end
