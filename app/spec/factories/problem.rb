# frozen_string_literal: true

FactoryBot.define do
  factory :problem do
    title { "My New Problem" }
    description { "This is a very new problem" }
    difficulty { :easy }
    memory_limit_kb { 256000 }  # 256 MB
    time_limit_sec { 1.0 }       # 1 second
    total_submissions { 0 }
    accepted_submissions { 0 }
    hidden { false }  # Tests typically use visible problems unless testing hidden behavior
    # Don't set constraints here - it's a has_many association
    # Create associated constraints separately if needed in specific tests
  end
end
