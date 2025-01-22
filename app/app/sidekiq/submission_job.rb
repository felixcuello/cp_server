class SubmissionJob
  include Sidekiq::Job

  def perform(*args)
  end
end
