# frozen_string_literal: true

require "json"

namespace :problems do
  desc "Create problems based on the JSON files in problems/*.json"

  task create: :environment do
    Dir.glob("problems/*.json").each do |file|
      data = JSON.parse(File.read(file))

      # Support both old format (direct fields) and new format (translations)
      if data["translations"]
        title = data["translations"]["en"]["title"]
      else
        title = data["title"]
      end

      problem = Problem.find_by(title: title)
      if problem
        puts "Skipping problem with title '#{title}' already exists. Skipping..."
        next
      end

      puts "Creating problem with title '#{title}'!"

      # Support both formats for description
      if data["translations"]
        description = data["translations"]["en"]["description"]
        # Constraints can be in translations or at root level
        constraints = data["translations"]["en"]["constraints"] || data["constraints"] || []
      else
        description = data["description"]
        constraints = data["constraints"] || []
      end

      difficulty = data["difficulty"]
      tags = data["tags"]
      examples = data["examples"]

      # Handle both memory_limit_kb and memory_limit_mb for compatibility
      memory_limit_kb = if data["memory_limit_mb"]
                          data["memory_limit_mb"].to_i * 1024
                        else
                          data["memory_limit_kb"].to_i
                        end
      time_limit_sec = data["time_limit_sec"].to_i

      # Read hidden field from JSON, defaulting to true if not present
      hidden = data.key?("hidden") ? data["hidden"] : true

      # Read ignore_output_line_order field from JSON, defaulting to false if not present
      ignore_output_line_order = data.key?("ignore_output_line_order") ? data["ignore_output_line_order"] : false

      # Get testing_mode from JSON, default to stdin_stdout
      testing_mode = data["testing_mode"] || "stdin_stdout"

      problem = Problem.create!(
        title: title,
        description: description,
        difficulty: difficulty.to_sym,
        memory_limit_kb: memory_limit_kb,
        time_limit_sec: time_limit_sec,
        hidden: hidden,
        ignore_output_line_order: ignore_output_line_order,
        testing_mode: testing_mode
      )

      # Create translations if new format
      if data["translations"]
        data["translations"].each do |locale, translation_data|
          ProblemTranslation.create!(
            problem: problem,
            locale: locale,
            title: translation_data["title"],
            description: translation_data["description"]
          )
        end
      end

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
          description: example["description"],
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

        # Create constraint translations if new format
        if data["translations"]
          data["translations"].each do |locale, translation_data|
            constraint_descriptions = translation_data["constraints"] || []
            if constraint_descriptions[sort_order].present?
              ConstraintTranslation.create!(
                constraint: constraint,
                locale: locale,
                description: constraint_descriptions[sort_order]
              )
            end
          end
        end
      end

      # Load templates and testers for function-based problems
      if problem.function_based?
        problem_file_basename = File.basename(file, ".problem.json")
        problem_dir = File.dirname(file)
        load_templates_for_problem(problem, problem_dir, problem_file_basename, data)
        load_testers_for_problem(problem, problem_dir, problem_file_basename)
      end
    end
  end

  namespace :create do
    desc "Force create/update problems based on the JSON files in problems/*.json (updates existing problems)"
    task force: :environment do
      Dir.glob("problems/*.json").each do |file|
        data = JSON.parse(File.read(file))

        # Support both old format (direct fields) and new format (translations)
        if data["translations"]
          title = data["translations"]["en"]["title"]
          description = data["translations"]["en"]["description"]
        else
          title = data["title"]
          description = data["description"]
        end

        problem = Problem.find_by(title: title)
        if problem
          puts "Updating problem with title '#{title}'!"

          # Destroy existing examples and constraints
          problem.examples.destroy_all
          problem.constraints.destroy_all
          problem.problem_tags.destroy_all
          problem.problem_templates.destroy_all
          problem.problem_testers.destroy_all
          problem.translations.destroy_all
        else
          puts "Creating problem with title '#{title}'!"
          problem = Problem.new
        end

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

        # Read ignore_output_line_order field from JSON, defaulting to false if not present
        ignore_output_line_order = data.key?("ignore_output_line_order") ? data["ignore_output_line_order"] : false

        # Get testing_mode from JSON, default to stdin_stdout
        testing_mode = data["testing_mode"] || "stdin_stdout"

        problem.update!(
          title: title,
          description: description,
          difficulty: difficulty.to_sym,
          memory_limit_kb: memory_limit_kb,
          time_limit_sec: time_limit_sec,
          hidden: hidden,
          ignore_output_line_order: ignore_output_line_order,
          testing_mode: testing_mode
        )

        # Create translations if new format
        if data["translations"]
          data["translations"].each do |locale, translation_data|
            ProblemTranslation.create!(
              problem: problem,
              locale: locale,
              title: translation_data["title"],
              description: translation_data["description"]
            )
          end
        end

        tags.each do |tag_name|
          tag = Tag.find_or_create_by!(name: tag_name)
          problem.tags << tag
        end

        examples.each_with_index do |example_data, sort_order|
          example = Example.create!(
            problem: problem,
            is_hidden: example_data["is_hidden"],
            input: example_data["input"].to_s,
            output: example_data["output"].to_s,
            description: example_data["description"],
            sort_order: sort_order
          )

          problem.examples << example
        end

        constraints.each_with_index do |constraint_description, sort_order|
          constraint = Constraint.create!(
            problem: problem,
            description: constraint_description,
            sort_order: sort_order
          )

          problem.constraints << constraint

          # Create constraint translations if new format
          if data["translations"]
            data["translations"].each do |locale, translation_data|
              constraint_descriptions = translation_data["constraints"] || []
              if constraint_descriptions[sort_order].present?
                ConstraintTranslation.create!(
                  constraint: constraint,
                  locale: locale,
                  description: constraint_descriptions[sort_order]
                )
              end
            end
          end
        end

        # Load templates and testers for function-based problems
        if problem.function_based?
          problem_file_basename = File.basename(file, ".problem.json")
          problem_dir = File.dirname(file)
          load_templates_for_problem(problem, problem_dir, problem_file_basename, data)
          load_testers_for_problem(problem, problem_dir, problem_file_basename)
        end
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

  private

  def load_templates_for_problem(problem, problem_dir, problem_basename, data)
    # Look for template files: multiply_list.template.cpp, multiply_list.template.c, etc.
    template_pattern = File.join(problem_dir, "#{problem_basename}.template.*")
    template_files = Dir.glob(template_pattern)

    return if template_files.empty?

    puts "   📝 Loading templates..."

    template_files.each do |template_file|
      extension = File.extname(template_file)[1..-1] # Remove leading dot
      language = find_language_by_extension(extension)

      unless language
        puts "      ⚠️  Unknown language extension: .#{extension}, skipping #{File.basename(template_file)}"
        next
      end

      template_code = File.read(template_file)
      function_signature = data["function_signature"]

      # Delete existing template if updating
      problem.problem_templates.where(programming_language: language).destroy_all

      ProblemTemplate.create!(
        problem: problem,
        programming_language: language,
        template_code: template_code,
        function_signature: function_signature
      )

      puts "      ✅ Template loaded for #{language.name}"
    end
  end

  def load_testers_for_problem(problem, problem_dir, problem_basename)
    # Look for tester files: multiply_list.tester.cpp, multiply_list.tester.c, etc.
    tester_pattern = File.join(problem_dir, "#{problem_basename}.tester.*")
    tester_files = Dir.glob(tester_pattern)

    return if tester_files.empty?

    puts "   🧪 Loading testers..."

    tester_files.each do |tester_file|
      extension = File.extname(tester_file)[1..-1] # Remove leading dot
      language = find_language_by_extension(extension)

      unless language
        puts "      ⚠️  Unknown language extension: .#{extension}, skipping #{File.basename(tester_file)}"
        next
      end

      tester_code = File.read(tester_file)

      # Delete existing tester if updating
      problem.problem_testers.where(programming_language: language).destroy_all

      ProblemTester.create!(
        problem: problem,
        programming_language: language,
        tester_code: tester_code
      )

      puts "      ✅ Tester loaded for #{language.name}"
    end
  end

  def find_language_by_extension(extension)
    case extension.downcase
    when "cpp", "cc", "cxx"
      ProgrammingLanguage.find_by(name: "C++11")
    when "c"
      ProgrammingLanguage.find_by(name: "C")
    when "py"
      ProgrammingLanguage.find_by(name: "Python 3")
    when "js"
      ProgrammingLanguage.find_by(name: "Javascript (NodeJS)")
    when "rb"
      ProgrammingLanguage.find_by(name: "Ruby")
    else
      nil
    end
  end
end
