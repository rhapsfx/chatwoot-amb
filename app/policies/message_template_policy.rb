class MessageTemplatePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
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

  def render_template?
    true
  end

  def from_apple_message?
    @account_user.administrator?
  end

  def attach_files?
    @account_user.administrator?
  end

  def remove_attachment?
    @account_user.administrator?
  end

  def reorder_attachments?
    @account_user.administrator?
  end
end

MessageTemplatePolicy.prepend_mod_with('MessageTemplatePolicy')
