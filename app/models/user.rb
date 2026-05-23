class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :projects, dependent: :destroy
  has_many :experiments, through: :projects
  has_many :json_results, through: :experiments

  validates :email, presence: true, uniqueness: true

  before_create :generate_api_token
  before_save :ensure_api_token, if: -> { api_token.blank? }


  private

  def generate_api_token
    self.api_token = SecureRandom.hex(32)
  end

  def regenerate_api_token!
    update!(api_token: SecureRandom.hex(32))
  end

  def ensure_api_token
    generate_api_token if api_token.blank?
  end
end
