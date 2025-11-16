class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Removed :registerable since this is a private server (admins create accounts manually)
  devise :database_authenticatable,
         :rememberable, :validatable, :timeoutable
end
