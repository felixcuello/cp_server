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
      
      # Handle both memory_limit_kb and memory_limit_mb for compatibility
      memory_limit_kb = if data["memory_limit_mb"]
                          data["memory_limit_mb"].to_i * 1024
                        else
                          data["memory_limit_kb"].to_i
                        end
      time_limit_sec = data["time_limit_sec"].to_i
      
      # Read hidden field from JSON, defaulting to true if not present
      hidden = data.key?("hidden") ? data["hidden"] : true

      problem = Problem.create!(
        title: title,
        description: description,
        difficulty: difficulty.to_sym,
        memory_limit_kb: memory_limit_kb,
        time_limit_sec: time_limit_sec,
        hidden: hidden
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

  task destroy: :environment do
    puts "Destroying all problems, examples, constraints, tags, and problem_tags"
    Problem.transaction do
      Example.destroy_all
      Constraint.destroy_all
      ProblemTag.destroy_all
      Tag.destroy_all
      Submission.destroy_all
      Problem.destroy_all
    end
  end
end
