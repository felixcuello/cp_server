# frozen_string_literal: true

require "json"

namespace :languages do
  desc "Create languages based on the JSON files in languages/*.json"

  task create: :environment do
    Dir.glob("languages/*.json").each do |file|
      data = JSON.parse(File.read(file))

      language = ProgrammingLanguage.find_by(name: data["name"])

      if language
        puts "Skipping #{data["name"]} as it already exists"
        next
      end

      puts "Adding #{data["name"]} language"

      ProgrammingLanguage.create!(
        name: data["name"],
        memory_limit_mb: data["memory_limit_mb"],
        time_limit_sec: data["time_limit_sec"],
        compiler_binary: data["compiler_binary"],
        compiler_flags: data["compiler_flags"],
        interpreter_binary: data["interpreter_binary"],
        interpreter_flags: data["interpreter_flags"]
      )
    end
  end
end
