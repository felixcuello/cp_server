# frozen_string_literal: true

require "json"

namespace :contests do
  desc "Create contests and their problems from contests/*/contest.json and contests/*/*.problem.json"

  task create: :environment do
    # Find all contest directories
    contest_dirs = Dir.glob("contests/*/").sort

    if contest_dirs.empty?
      puts "No contest directories found in contests/"
      exit
    end

    contest_dirs.each do |contest_dir|
      contest_json_path = File.join(contest_dir, "contest.json")

      unless File.exist?(contest_json_path)
        puts "⚠️  Skipping #{contest_dir} - no contest.json found"
        next
      end

      puts "\n" + "="*80
      puts "📁 Processing contest directory: #{contest_dir}"
      puts "="*80

      # Load and create contest
      contest_data = JSON.parse(File.read(contest_json_path))
      contest = create_or_find_contest(contest_data)

      if contest.nil?
        puts "❌ Failed to create/find contest. Skipping problems."
        next
      end

      # Find all problem files in this contest directory
      problem_files = Dir.glob(File.join(contest_dir, "*.problem.json")).sort

      if problem_files.empty?
        puts "   ⚠️  No problem files found in #{contest_dir}"
        next
      end

      puts "\n   Found #{problem_files.count} problem file(s)"

      # Create problems for this contest
      problem_files.each do |problem_file|
        create_problem_for_contest(problem_file, contest)
      end
    end

    puts "\n" + "="*80
    puts "✅ Contest import completed!"
    puts "="*80
  end

  desc "Force create/update contests and problems from contests directory (updates existing)"
  namespace :create do
    task force: :environment do
      contest_dirs = Dir.glob("contests/*/").sort

      if contest_dirs.empty?
        puts "No contest directories found in contests/"
        exit
      end

      contest_dirs.each do |contest_dir|
        contest_json_path = File.join(contest_dir, "contest.json")

        unless File.exist?(contest_json_path)
          puts "⚠️  Skipping #{contest_dir} - no contest.json found"
          next
        end

        puts "\n" + "="*80
        puts "📁 Processing contest directory: #{contest_dir}"
        puts "="*80

        # Load and create/update contest
        contest_data = JSON.parse(File.read(contest_json_path))
        contest = create_or_update_contest(contest_data)

        if contest.nil?
          puts "❌ Failed to create/update contest. Skipping problems."
          next
        end

        # Find all problem files
        problem_files = Dir.glob(File.join(contest_dir, "*.problem.json")).sort

        if problem_files.empty?
          puts "   ⚠️  No problem files found in #{contest_dir}"
          next
        end

        puts "\n   Found #{problem_files.count} problem file(s)"

        # Create/update problems
        problem_files.each do |problem_file|
          create_or_update_problem_for_contest(problem_file, contest)
        end
      end

      puts "\n" + "="*80
      puts "✅ Contest import/update completed!"
      puts "="*80
    end
  end

  task destroy: :environment do
    puts "Destroying all contests, their problems, examples, constraints, and submissions..."

    Contest.transaction do
      # Get all contest-associated problems
      contest_problems = Problem.where.not(contest_id: nil)

      puts "   Found #{contest_problems.count} contest problems to destroy"

      # Destroy associated data
      Example.where(problem_id: contest_problems.ids).destroy_all
      Constraint.where(problem_id: contest_problems.ids).destroy_all
      ProblemTag.where(problem_id: contest_problems.ids).destroy_all
      Submission.where(problem_id: contest_problems.ids).destroy_all

      # Destroy the problems themselves
      contest_problems.destroy_all

      # Destroy all contests
      Contest.destroy_all
    end

    puts "✅ All contests and their problems destroyed!"
  end

  private

  def create_or_find_contest(data)
    name = data["name"]

    existing_contest = Contest.find_by(name: name)
    if existing_contest
      puts "   ⏭️  Contest '#{name}' already exists (ID: #{existing_contest.id}). Skipping creation..."
      return existing_contest
    end

    puts "   ✨ Creating contest '#{name}'"

    contest = Contest.create!(
      name: name,
      description: data["description"],
      rules: data["rules"],
      start_time: parse_time(data["start_time"]),
      end_time: parse_time(data["end_time"]),
      penalty_minutes: data["penalty_minutes"] || 0
    )

    puts "   ✅ Contest created (ID: #{contest.id})"
    contest
  rescue StandardError => e
    puts "   ❌ Error creating contest '#{name}': #{e.message}"
    nil
  end

  def create_or_update_contest(data)
    name = data["name"]

    contest = Contest.find_by(name: name)

    if contest
      puts "   🔄 Updating contest '#{name}' (ID: #{contest.id})"
    else
      puts "   ✨ Creating contest '#{name}'"
      contest = Contest.new
    end

    contest.update!(
      name: name,
      description: data["description"],
      rules: data["rules"],
      start_time: parse_time(data["start_time"]),
      end_time: parse_time(data["end_time"]),
      penalty_minutes: data["penalty_minutes"] || 0
    )

    puts "   ✅ Contest saved (ID: #{contest.id})"
    contest
  rescue StandardError => e
    puts "   ❌ Error saving contest '#{name}': #{e.message}"
    nil
  end

  def create_problem_for_contest(file, contest)
    data = JSON.parse(File.read(file))
    title = data["title"]

    problem = Problem.find_by(title: title)
    if problem
      puts "   ⏭️  Problem '#{title}' already exists. Skipping..."
      return
    end

    puts "   ✨ Creating problem '#{title}'"
    create_problem(data, contest, file)
  rescue StandardError => e
    puts "   ❌ Error creating problem from #{file}: #{e.message}"
  end

  def create_or_update_problem_for_contest(file, contest)
    data = JSON.parse(File.read(file))
    title = data["title"]

    problem = Problem.find_by(title: title)

    if problem
      puts "   🔄 Updating problem '#{title}' (ID: #{problem.id})"
      # Clear existing associations
      problem.examples.destroy_all
      problem.constraints.destroy_all
      problem.problem_tags.destroy_all
      problem.problem_templates.destroy_all
      problem.problem_testers.destroy_all
    else
      puts "   ✨ Creating problem '#{title}'"
      problem = Problem.new
    end

    update_problem(problem, data, contest, file)
  rescue StandardError => e
    puts "   ❌ Error saving problem from #{file}: #{e.message}"
  end

  def create_problem(data, contest, file)
    problem = Problem.new
    update_problem(problem, data, contest, file)
  end

  def update_problem(problem, data, contest, file)
    # Handle both memory_limit_kb and memory_limit_mb for compatibility
    memory_limit_kb = if data["memory_limit_mb"]
                        data["memory_limit_mb"].to_i * 1024
                      else
                        data["memory_limit_kb"].to_i
                      end

    # For contest problems, default to hidden: true (problems become public after contest ends)
    # This can be overridden by explicitly setting hidden: false in the JSON
    # Note: Contest problems should typically be hidden until the contest ends
    hidden = if data.key?("hidden")
               data["hidden"]
             else
               true  # Default to hidden for contest problems
             end

    # Get testing_mode from JSON, default to stdin_stdout
    testing_mode = data["testing_mode"] || "stdin_stdout"

    problem.update!(
      title: data["title"],
      description: data["description"],
      difficulty: data["difficulty"].to_sym,
      memory_limit_kb: memory_limit_kb,
      time_limit_sec: data["time_limit_sec"].to_i,
      hidden: hidden,
      testing_mode: testing_mode,
      contest: contest
    )

    # Add tags
    data["tags"]&.each do |tag_name|
      tag = Tag.find_or_create_by!(name: tag_name)
      problem.tags << tag unless problem.tags.include?(tag)
    end

    # Add examples
    data["examples"]&.each_with_index do |example_data, sort_order|
      Example.create!(
        problem: problem,
        is_hidden: example_data["is_hidden"],
        input: example_data["input"].to_s,
        output: example_data["output"].to_s,
        description: example_data["description"],
        sort_order: sort_order
      )
    end

    # Add constraints
    data["constraints"]&.each_with_index do |constraint_description, sort_order|
      Constraint.create!(
        problem: problem,
        description: constraint_description,
        sort_order: sort_order
      )
    end

    puts "      ✅ Problem '#{data["title"]}' saved successfully"

    # Load templates and testers for function-based problems
    if problem.function_based?
      problem_file_basename = File.basename(file, ".problem.json")
      contest_dir = File.dirname(file)
      create_templates_for_problem(problem, contest_dir, problem_file_basename, data)
      create_testers_for_problem(problem, contest_dir, problem_file_basename)
    end
  end

  def create_templates_for_problem(problem, contest_dir, problem_basename, data)
    # Look for template files: 01.template.cpp, 01.template.c, etc.
    template_pattern = File.join(contest_dir, "#{problem_basename}.template.*")
    template_files = Dir.glob(template_pattern)

    return if template_files.empty?

    puts "      📝 Loading templates..."

    template_files.each do |template_file|
      extension = File.extname(template_file)[1..-1] # Remove leading dot
      language = find_language_by_extension(extension)

      unless language
        puts "         ⚠️  Unknown language extension: .#{extension}, skipping #{File.basename(template_file)}"
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

      puts "         ✅ Template loaded for #{language.name}"
    end
  end

  def create_testers_for_problem(problem, contest_dir, problem_basename)
    # Look for tester files: 01.tester.cpp, 01.tester.c, etc.
    tester_pattern = File.join(contest_dir, "#{problem_basename}.tester.*")
    tester_files = Dir.glob(tester_pattern)

    return if tester_files.empty?

    puts "      🧪 Loading testers..."

    tester_files.each do |tester_file|
      extension = File.extname(tester_file)[1..-1] # Remove leading dot
      language = find_language_by_extension(extension)

      unless language
        puts "         ⚠️  Unknown language extension: .#{extension}, skipping #{File.basename(tester_file)}"
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

      puts "         ✅ Tester loaded for #{language.name}"
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

  def parse_time(time_string)
    return nil if time_string.nil?

    # Try to parse as ISO8601 format first
    Time.zone.parse(time_string)
  rescue ArgumentError
    # Fallback to other formats if needed
    Time.zone.parse(time_string)
  end
end
