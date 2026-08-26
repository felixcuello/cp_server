# frozen_string_literal: true

FactoryBot.define do
  factory :sandbox_access_token_checkin do
    sandbox_access_token
    first_name { "Ana" }
    last_name { "Perez" }
    id_type { :dni }
    sequence(:document_number) { |n| "1000000#{n}" }
    ip_address { "127.0.0.1" }
  end
end
