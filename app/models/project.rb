class Project < ApplicationRecord
  belongs_to :user
  has_many :experiments, dependent: :destroy
  has_many :json_results, through: :experiments

  validates :name, presence: true
  validates :share_mode, inclusion: { in: %w[private view edit] }, allow_nil: true

  before_create :generate_share_token

  # Scopes для оптимизации запросов
  scope :with_experiments, -> { includes(:experiments) }
  scope :with_full_data, -> { includes(experiments: :json_results) }
  scope :ordered_by_created, -> { order(created_at: :desc) }
  scope :select_for_index, -> { select(:id, :name, :description, :created_at, :experiments_count) }

  def recent_experiments(limit = 5)
    experiments.order(created_at: :desc).limit(limit)
  end

  def shared?
    share_mode.present? && share_mode != 'private'
  end

  def editable_by_link?
    share_mode == 'edit'
  end

  def viewable_by_link?
    share_mode.in?(%w[view edit])
  end

  def regenerate_share_token!
    update(share_token: SecureRandom.urlsafe_base64(32))
  end

  def disable_sharing!
    update(share_mode: 'private', share_token: nil)
  end

  private

  def generate_share_token
    self.share_token ||= SecureRandom.urlsafe_base64(32)
  end
end