class AgentBotPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def avatar?
    @account_user.administrator?
  end

  def reset_access_token?
    @account_user.administrator?
  end

  def bulk_assign?
    @account_user.administrator?
  end

  def import_from_bot_config?
    @account_user.administrator?
  end

  def compile?
    @account_user.administrator?
  end

  def duplicate?
    @account_user.administrator?
  end

  def update_node?
    @account_user.administrator?
  end

  def validate?
    @account_user.administrator? || @account_user.agent?
  end

  def preview?
    @account_user.administrator? || @account_user.agent?
  end

  def simulate?
    @account_user.administrator? || @account_user.agent?
  end

  # Version management permissions
  def activate?
    @account_user.administrator?
  end

  def archive?
    @account_user.administrator?
  end

  def restore?
    @account_user.administrator?
  end

  def compare?
    @account_user.administrator? || @account_user.agent?
  end

  def create_version?
    @account_user.administrator?
  end

  def publish?
    @account_user.administrator?
  end

  def unpublish?
    @account_user.administrator?
  end

  def versions?
    @account_user.administrator? || @account_user.agent?
  end

  def version_tree?
    @account_user.administrator? || @account_user.agent?
  end

  # Handler methods permissions
  def handler_methods?
    @account_user.administrator? || @account_user.agent?
  end

  def search?
    @account_user.administrator? || @account_user.agent?
  end

  def search_handler_methods?
    @account_user.administrator? || @account_user.agent?
  end

  def validate_handler_method?
    @account_user.administrator? || @account_user.agent?
  end
end

AgentBotPolicy.prepend_mod_with('AgentBotPolicy')
