class User < ApplicationRecord
  devise :database_authenticatable, :registerable, 
         :recoverable, :rememberable, :validatable

  has_many :projects, dependent: :destroy
  has_many :experiments, through: :projects
  has_many :json_results, through: :experiments

  validates :email, presence: true, uniqueness: true
end
