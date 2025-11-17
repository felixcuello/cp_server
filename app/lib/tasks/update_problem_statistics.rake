# frozen_string_literal: true

namespace :problems do
  desc "Update statistics for all problems"
  task update_statistics: :environment do
    puts "Updating statistics for all problems..."
    
    Problem.find_each do |problem|
      problem.update_statistics!
      puts "Updated problem ##{problem.id}: #{problem.title} - #{problem.total_submissions} submissions, #{problem.accepted_submissions} accepted (#{problem.acceptance_rate}%)"
    end
    
    puts "\nDone! Updated #{Problem.count} problems."
  end
  
  desc "Update user problem statuses based on existing submissions"
  task update_user_statuses: :environment do
    puts "Updating user problem statuses..."
    
    # Get all unique user-problem combinations from submissions
    submissions = Submission.select(:user_id, :problem_id).distinct
    
    submissions.each do |submission|
      user = User.find(submission.user_id)
      problem = Problem.find(submission.problem_id)
      
      # Check if user has any accepted submission for this problem
      has_accepted = Submission.where(user: user, problem: problem, status: 'accepted').exists?
      
      user_status = UserProblemStatus.find_or_initialize_by(user: user, problem: problem)
      
      if has_accepted
        user_status.status = 'solved'
      else
        user_status.status = 'attempted'
      end
      
      user_status.save!
      
      puts "Updated #{user.email} - Problem ##{problem.id}: #{user_status.status}"
    end
    
    puts "\nDone! Updated #{submissions.count} user-problem statuses."
  end
end
