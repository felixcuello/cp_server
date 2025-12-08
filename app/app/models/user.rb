class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Removed :registerable since this is a private server (admins create accounts manually)
  devise :database_authenticatable,
         :rememberable, :validatable, :timeoutable

  # Locales
  LOCALES = %w[en es].freeze

  # Roles enum: user (0), admin (1)
  enum :role, {
    user: 0,
    admin: 1
  }

  has_many :submissions
  has_many :user_problem_statuses
  has_many :solved_problems, -> { where(user_problem_statuses: { status: 'solved' }) },
           through: :user_problem_statuses, source: :problem

  has_many :contest_participants
  has_many :contests, through: :contest_participants
  has_many :contest_submissions, -> { where.not(contest_id: nil) }, class_name: 'Submission'

  validates :locale, inclusion: { in: LOCALES }, allow_nil: true

  # Helper method to check if user is admin
  def admin?
    role == 'admin'
  end

  # Override locale getter to ensure we always have a valid locale
  def locale
    super.presence || I18n.default_locale.to_s
  end
end
