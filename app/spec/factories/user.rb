# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@domain.com" }
    sequence(:alias) { |n| "user#{n}" }
    sequence(:first_name) { |n| "User" }
    sequence(:last_name) { |n| "Test#{n}" }
    password { "password" }
  end
end
