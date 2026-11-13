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
      # Bots can access all inboxes in their account
      return @account.inboxes if @user.is_a?(AgentBot)

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
    # Allow bots to access inboxes (they need this for API calls)
    return true if @user.is_a?(AgentBot)

    # Users with inbox_manage can access assigned inboxes or all if admin
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def create?
    # Bots cannot create inboxes
    return false if @user.is_a?(AgentBot)

    # Only admins can create inboxes
    @account_user.administrator?
  end

  def update?
    # Bots cannot update inboxes
    return false if @user.is_a?(AgentBot)

    # Users with inbox_manage can edit assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def destroy?
    # Bots cannot delete inboxes
    return false if @user.is_a?(AgentBot)

    # Only admins can delete inboxes
    @account_user.administrator?
  end

  def campaigns?
    # Bots cannot manage campaigns
    return false if @user.is_a?(AgentBot)

    # Users with inbox_manage can manage campaigns for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def set_agent_bot?
    # Bots cannot set other bots
    return false if @user.is_a?(AgentBot)

    # Users with inbox_manage can set agent bot for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def avatar?
    # Bots cannot update inbox avatars
    return false if @user.is_a?(AgentBot)

    # Users with inbox_manage can update avatar for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def sync_templates?
    # Bots cannot sync templates
    return false if @user.is_a?(AgentBot)

    # Users with inbox_manage can sync templates for assigned inboxes
    if @account_user.custom_role&.permissions&.include?('inbox_manage')
      user_is_assigned_to_inbox?
    else
      super
    end
  end

  def health?
    # Bots cannot check health
    return false if @user.is_a?(AgentBot)

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
