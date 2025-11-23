# frozen_string_literal: true

class Contest < ApplicationRecord
  has_many :problems, dependent: :nullify
  has_many :submissions, through: :problems
  has_many :contest_participants, dependent: :destroy
  has_many :participants, through: :contest_participants, source: :user

  validates :name, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :penalty_minutes, numericality: { greater_than_or_equal_to: 0 }
  validate :end_time_after_start_time

  # Check if contest is currently active
  def active?
    return false if start_time.nil? || end_time.nil?
    now = Time.current
    now >= start_time && now <= end_time
  end

  # Check if contest hasn't started yet
  def upcoming?
    return false if start_time.nil?
    Time.current < start_time
  end

  # Check if contest has ended
  def ended?
    return false if end_time.nil?
    Time.current > end_time
  end

  # Calculate contest duration in minutes
  def duration_minutes
    return 0 if start_time.nil? || end_time.nil?
    ((end_time - start_time) / 60).to_i
  end

  # Calculate time remaining until start or end
  # Returns hash with :type (:start or :end) and :seconds
  def time_remaining
    now = Time.current
    
    if upcoming?
      { type: :start, seconds: (start_time - now).to_i }
    elsif active?
      { type: :end, seconds: (end_time - now).to_i }
    else
      { type: :ended, seconds: 0 }
    end
  end

  # Check if a user is participating in this contest
  def user_participating?(user)
    return false if user.nil?
    contest_participants.exists?(user_id: user.id)
  end

  # Check if a user can access (view/submit) this contest
  # Admins can always access
  # Regular users can access if they're participants and contest is active or ended
  def can_user_access?(user)
    return false if user.nil?
    return true if user.admin?
    user_participating?(user) && (active? || ended?)
  end

  private

  def end_time_after_start_time
    return if start_time.nil? || end_time.nil?
    
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
