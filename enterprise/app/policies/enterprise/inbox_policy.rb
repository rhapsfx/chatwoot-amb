module Enterprise::InboxPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      # If user has inbox_manage permission or is administrator, show all inboxes
      if @account_user.administrator? || @account_user.custom_role&.permissions&.include?('inbox_manage')
        @account.inboxes
      else
        # Otherwise, only show assigned inboxes
        @user.assigned_inboxes
      end
    end
  end

  def show?
    # Users with inbox_manage can access assigned inboxes or all if admin
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def create?
    # Only admins can create inboxes
    @account_user.administrator?
  end

  def update?
    # Users with inbox_manage can edit assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def destroy?
    # Only admins can delete inboxes
    @account_user.administrator?
  end

  def campaigns?
    # Users with inbox_manage can manage campaigns for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def set_agent_bot?
    # Users with inbox_manage can set agent bot for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def avatar?
    # Users with inbox_manage can update avatar for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def sync_templates?
    # Users with inbox_manage can sync templates for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def health?
    # Users with inbox_manage can check health for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  private

  def user_is_assigned_to_inbox?
    @user.assigned_inboxes.include?(record)
  end
end
