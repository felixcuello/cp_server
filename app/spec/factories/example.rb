# froze_string_literal: true

FactoryBot.define do
  factory :example do
    input { "MyString" }
    output { "MyString" }
    sort_order { 1 }
    problem { nil }

    trait :with_problem do
      problem { FactoryBot.create(:problem) }
    end
  end
end
