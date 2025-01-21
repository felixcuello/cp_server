# frozen_string_literal: true

FactoryBot.define do
  factory :problem do
    title { "My New Problem" }
    description { "This is a very new problem" }
    difficulty { :easy }
    constraints { "1 <= n <= 10^5" }
  end
end
