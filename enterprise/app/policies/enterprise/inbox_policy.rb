module Enterprise::InboxPolicy
  def create?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end

  def update?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end

  def destroy?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end

  def campaigns?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end

  def set_agent_bot?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end

  def avatar?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end

  def sync_templates?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end

  def health?
    @account_user.custom_role&.permissions&.include?('inbox_manage') || super
  end
end