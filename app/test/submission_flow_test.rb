#!/usr/bin/env ruby
# Run with: docker exec cp_server-sidekiq-1 bundle exec ruby test/submission_flow_test.rb

require_relative '../config/environment'

puts "=" * 80
puts "Testing Submission Flow with nsjail"
puts "=" * 80

# Find or create a user
user = User.first || User.create!(
  email: "test@example.com",
  alias: "testuser",
  first_name: "Test",
  last_name: "User",
  password: "password123",
  password_confirmation: "password123"
)

# Find or create Python language
python_language = ProgrammingLanguage.find_by(name: "Python 3")
unless python_language
  puts "Creating Python 3 language..."
  python_language = ProgrammingLanguage.create!(
    name: "Python 3",
    compiler_binary: "",
    compiler_flags: "",
    interpreter_binary: "python3",
    interpreter_flags: "",
    memory_limit_kb: 4096,
    time_limit_sec: 5,
    extension: "py"
  )
end

# Create a simple problem
problem = Problem.create!(
  title: "Add Two Numbers",
  description: "Given two integers, output their sum.",
  difficulty: :easy,
  time_limit_sec: 5,
  memory_limit_kb: 262144,
  total_submissions: 0,
  accepted_submissions: 0,
  hidden: false
)

# Add example
problem.examples.create!(
  input: "5 3\n",
  output: "8\n",
  sort_order: 1
)

puts "\nProblem created: #{problem.title}"
puts "Example: input='5 3', expected output='8'"

# Test 1: Valid submission
puts "\n" + "-" * 80
puts "Test 1: Valid Python code"
puts "-" * 80

submission1 = Submission.create!(
  user: user,
  problem: problem,
  programming_language: python_language,
  source_code: "a, b = map(int, input().split())\nprint(a + b)",
  status: 'pending'
)

puts "Submission created: ID=#{submission1.id}"
puts "Source code: #{submission1.source_code.inspect}"

submission1.run!

puts "\nResults:"
puts "  Status: #{submission1.reload.status}"
puts "  Time used: #{submission1.time_used}s"
puts "  Expected: ACCEPTED"

if submission1.status == Submission::ACCEPTED
  puts "  ✅ PASS: Submission accepted correctly"
else
  puts "  ❌ FAIL: Expected ACCEPTED, got #{submission1.status}"
end

# Test 2: Wrong answer
puts "\n" + "-" * 80
puts "Test 2: Wrong answer"
puts "-" * 80

submission2 = Submission.create!(
  user: user,
  problem: problem,
  programming_language: python_language,
  source_code: "print(42)",
  status: 'pending'
)

submission2.run!

puts "\nResults:"
puts "  Status: #{submission2.reload.status}"
puts "  Time used: #{submission2.time_used}s"
puts "  Expected: WRONG_ANSWER"

if submission2.status.include?(Submission::WRONG_ANSWER)
  puts "  ✅ PASS: Wrong answer detected correctly"
else
  puts "  ❌ FAIL: Expected WRONG_ANSWER, got #{submission2.status}"
end

# Test 3: Time limit exceeded
puts "\n" + "-" * 80
puts "Test 3: Time limit exceeded"
puts "-" * 80

submission3 = Submission.create!(
  user: user,
  problem: problem,
  programming_language: python_language,
  source_code: "while True: pass",
  status: 'pending'
)

submission3.run!

puts "\nResults:"
puts "  Status: #{submission3.reload.status}"
puts "  Time used: #{submission3.time_used}s"
puts "  Expected: TIME_LIMIT_EXCEEDED"

if submission3.status == Submission::TIME_LIMIT_EXCEEDED
  puts "  ✅ PASS: Time limit exceeded detected correctly"
else
  puts "  ❌ FAIL: Expected TIME_LIMIT_EXCEEDED, got #{submission3.status}"
end

# Verify database values
puts "\n" + "=" * 80
puts "Database Verification"
puts "=" * 80

submissions = Submission.where(problem: problem).order(created_at: :desc).limit(3)
submissions.each do |s|
  puts "\nSubmission ID: #{s.id}"
  puts "  Status: #{s.status}"
  puts "  Time used: #{s.time_used}s"
  puts "  Created at: #{s.created_at}"
  puts "  User: #{s.user.email}"
  puts "  Language: #{s.programming_language.name}"
end

puts "\n" + "=" * 80
puts "All tests completed!"
puts "=" * 80
