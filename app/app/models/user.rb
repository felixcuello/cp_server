class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Removed :registerable since this is a private server (admins create accounts manually)
  devise :database_authenticatable,
         :rememberable, :validatable, :timeoutable
         
  has_many :submissions
  has_many :user_problem_statuses
  has_many :solved_problems, -> { where(user_problem_statuses: { status: 'solved' }) }, 
           through: :user_problem_statuses, source: :problem
end
