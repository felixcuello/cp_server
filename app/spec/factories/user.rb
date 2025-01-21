# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "someone@domain.com" }
    password { "password" }
  end
end
