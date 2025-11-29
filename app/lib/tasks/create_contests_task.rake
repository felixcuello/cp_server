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
    create_problem(data, contest)
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
    else
      puts "   ✨ Creating problem '#{title}'"
      problem = Problem.new
    end

    update_problem(problem, data, contest)
  rescue StandardError => e
    puts "   ❌ Error saving problem from #{file}: #{e.message}"
  end

  def create_problem(data, contest)
    problem = Problem.new
    update_problem(problem, data, contest)
  end

  def update_problem(problem, data, contest)
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

    problem.update!(
      title: data["title"],
      description: data["description"],
      difficulty: data["difficulty"].to_sym,
      memory_limit_kb: memory_limit_kb,
      time_limit_sec: data["time_limit_sec"].to_i,
      hidden: hidden,
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
