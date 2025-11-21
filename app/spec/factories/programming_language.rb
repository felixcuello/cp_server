# frozen_string_literal: true

FactoryBot.define do
  factory :programming_language do
    name { "Ruby" }
    compiler_binary { "" }
    compiler_flags { "" }
    interpreter_binary { "ruby" }
    interpreter_flags { "" }
    memory_limit_kb { 4096 }
    time_limit_sec { 5 }
    extension { "rb" }

    trait :python do
      name { "Python 3" }
      compiler_binary { "" }
      compiler_flags { "" }
      interpreter_binary { "python3" }
      interpreter_flags { "" }
      memory_limit_kb { 4096 }
      time_limit_sec { 5 }
      extension { "py" }
    end
  end
end
