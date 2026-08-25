# frozen_string_literal: true

FactoryBot.define do
  factory :sandbox_access_token do
    sequence(:label) { |n| "Class #{n}" }
    token { SecureRandom.urlsafe_base64(24).delete("=") }
    valid_from { 1.minute.ago }
    expires_at { 2.hours.from_now }

    after(:build) do |token|
      next if token.programming_languages.any?

      token.programming_languages << create(:programming_language)
    end

    trait :upcoming do
      valid_from { 1.day.from_now }
      expires_at { 8.days.from_now }
    end

    trait :expired do
      valid_from { 2.days.ago }
      expires_at { 1.hour.ago }
      to_create { |instance| instance.save!(validate: false) }
    end

    trait :revoked do
      revoked_at { Time.current }
    end
  end
end
