class ExperimentPolicy < ApplicationPolicy
  def show?
    owner? || shared_via_token? || project_accessible?
  end

  def create?
    ProjectPolicy.new(user, record.project).update?
  end

  def update?
    owner? || project_editable?
  end

  def destroy?
    owner? || project_editable?
  end

  def manage_sharing?
    owner?
  end

  def download_json?
    owner?
  end

  private

  def owner?
    user.present? && record.owner_user.id == user.id
  end

  def shared_via_token?
    record.shared? && record.share_token.present?
  end

  def project_accessible?
    ProjectPolicy.new(user, record.project).show?
  end

  def project_editable?
    ProjectPolicy.new(user, record.project).update?
  end

  class Scope < Scope
    def resolve
      scope.joins(:project).where(projects: { user: user })
    end
  end
end