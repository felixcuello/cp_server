# frozen_string_literal: true

require "json"

namespace :problems do
  desc "Create problems based on the JSON files in problems/*.json"

  task create: :environment do
    Dir.glob("problems/*.json").each do |file|
      data = JSON.parse(File.read(file))

      title = data["title"]

      problem = Problem.find_by(title: title)
      if problem
        puts "Skipping problem with title '#{title}' already exists. Skipping..."
        next
      end

      puts "Creating problem with title '#{title}'!"

      description = data["description"]
      difficulty = data["difficulty"]
      tags = data["tags"]
      examples = data["examples"]
      constraints = data["constraints"]
      memory_limit_mb = data["memory_limit_mb"].to_i
      time_limit_sec = data["time_limit_sec"].to_i

      problem = Problem.create!(
        title: title,
        description: description,
        difficulty: difficulty.to_sym,
        memory_limit_mb: memory_limit_mb,
        time_limit_sec: time_limit_sec
      )

      tags.each do |tag|
        tag = Tag.find_or_create_by!(name: tag)
        problem.tags << tag
      end

      examples.each_with_index do |example, sort_order|
        example = Example.create!(
          problem: problem,
          is_hidden: example["is_hidden"],
          input: example["input"].to_s,
          output: example["output"].to_s,
          sort_order: sort_order
        )

        problem.examples << example
      end

      constraints.each_with_index do |constraint, sort_order|
        constraint = Constraint.create!(
          problem: problem,
          description: constraint,
          sort_order: sort_order
        )

        problem.constraints << constraint
      end
    end
  end
end
