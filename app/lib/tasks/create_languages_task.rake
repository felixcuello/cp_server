# frozen_string_literal: true

require "json"

namespace :languages do
  desc "Create languages based on the JSON files in languages/*.json"

  task create: :environment do
    Dir.glob("languages/*.json").each do |file|
      programming_language = JSON.parse(File.read(file))

      language = ProgrammingLanguage.find_by(name: programming_language["name"])

      if language
        puts "Skipping #{programming_language["name"]} as it already exists"
        next
      end

      puts "Adding #{programming_language["name"]} language"

      ProgrammingLanguage.create!(
        name: programming_language["name"],
        memory_limit_kb: programming_language["memory_limit_kb"],
        time_limit_sec: programming_language["time_limit_sec"],
        compiler_binary: programming_language["compiler_binary"],
        compiler_flags: programming_language["compiler_flags"],
        interpreter_binary: programming_language["interpreter_binary"],
        interpreter_flags: programming_language["interpreter_flags"],
        extension: programming_language["extension"]
      )
    end
  end
end
