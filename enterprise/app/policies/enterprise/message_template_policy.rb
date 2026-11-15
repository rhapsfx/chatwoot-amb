module Enterprise::MessageTemplatePolicy
  def index?
    @account_user.custom_role&.permissions&.include?('template_manage') || super
  end

  def show?
    @account_user.custom_role&.permissions&.include?('template_manage') || super
  end

  def create?
    @account_user.custom_role&.permissions&.include?('template_manage') || super
  end

  def update?
    @account_user.custom_role&.permissions&.include?('template_manage') || super
  end

  def destroy?
    @account_user.custom_role&.permissions&.include?('template_manage') || super
  end

  def render_template?
    @account_user.custom_role&.permissions&.include?('template_manage') || super
  end
end
