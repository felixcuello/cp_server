class SubmissionJob
  include Sidekiq::Job

  def perform(*args)
    submission = Submission.find(args.first)

    submission.update!(status: "running")
    submission.run!
  rescue StandardError => e
    File.write("/tmp/submission_job.log", "error: #{e.message}", mode: "a")
    File.write("/tmp/submission_job.log", "error: #{e.backtrace}", mode: "a")
  end
end
