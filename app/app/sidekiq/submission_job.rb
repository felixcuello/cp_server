class SubmissionJob
  include Sidekiq::Job

  def perform(*args)
    submission = Submission.find(args.first)

    submission.update!(status: "running")

    # Simulate a long-running job
    sleep 10

    submission.update!(status: "Wrong Answer")
  rescue StandardError => e
    File.write("/tmp/submission_job.log", "error: #{e.message}", mode: "a")
  end
end
