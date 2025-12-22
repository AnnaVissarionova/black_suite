class Experiment < ApplicationRecord
  belongs_to :project, counter_cache: true
  has_many :json_results, dependent: :destroy

  validates :name, presence: true

  delegate :user, to: :project, prefix: :owner

  before_create :generate_share_token

  # Scopes для оптимизации запросов
  scope :with_results, -> { includes(:json_results) }
  scope :ordered_by_created, -> { order(created_at: :desc) }
  scope :select_for_list, -> { select(:id, :name, :description, :created_at, :project_id) }

  # Кэшированная загрузка последнего результата
  def latest_result_cached
    Rails.cache.fetch([self, "latest_result", updated_at]) do
      json_results.order(created_at: :desc).first
    end
  end

  def latest_result
    json_results.order(created_at: :desc).first
  end

  def has_results?
    json_results_count > 0
  end

  def shared?
    share_token.present?
  end

  def regenerate_share_token!
    update(share_token: SecureRandom.urlsafe_base64(32))
  end

  def disable_sharing!
    update(share_token: nil)
  end

  private

  def generate_share_token
    self.share_token ||= SecureRandom.urlsafe_base64(32)
  end
end