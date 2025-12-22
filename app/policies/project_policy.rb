class ProjectPolicy < ApplicationPolicy
  def show?
    owner? || shared_via_token?
  end

  def show_experiment?
    show?
  end

  def create?
    user.present?
  end

  def update?
    owner? || editable_via_token?
  end

  def destroy?
    owner?
  end

  def manage_sharing?
    owner?
  end

  def shared?
    record.share_mode == 'view' && record.share_token.present?
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end

  def shared_via_token?
    record.shared? && record.share_token.present?
  end

  def editable_via_token?
    record.editable_by_link? && record.share_token.present?
  end

  class Scope < Scope
    def resolve
      scope.where(user: user)
    end
  end
end