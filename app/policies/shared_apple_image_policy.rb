class SharedAppleImagePolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def upload?
    @account_user.administrator?
  end

  def remove_image?
    @account_user.administrator?
  end

  def system_images?
    @account_user.administrator? || @account_user.agent?
  end

  def branding_images?
    @account_user.administrator? || @account_user.agent?
  end

  def template_images?
    @account_user.administrator? || @account_user.agent?
  end
end
