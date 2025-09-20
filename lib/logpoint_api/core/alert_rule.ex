defmodule LogpointApi.Core.AlertRule do
  @moduledoc false

  alias LogpointApi.Net.AlertRuleClient

  def create_alert_rule(req, token, alert_rule) do
    # TODO Implement
  end

  def list_alert_rules(req, token, params \\ %{}) do
    AlertRuleClient.get(req, "/AlertRules/lists_api", token, params)
  end

  def get_alert_rule_by_id(req, token, id) when is_binary(id) do
    AlertRuleClient.get(req, "/AlertRules/read_api", token, %{id: id})
  end

  def update_alert_rule(req, token, id, alert_rule) do
    # TODO Implement
  end

  def delete_alert_rules(req, token, ids) when is_list(ids) do
    AlertRuleClient.post(req, "/AlertRules/delete_api", token, %{ids: ids})
  end

  def activate_alert_rules(req, token, ids) when is_list(ids) do
    AlertRuleClient.post(req, "/AlertRules/activate_api", token, %{ids: ids})
  end

  def deactivate_alert_rules(req, token, ids) when is_list(ids) do
    AlertRuleClient.post(req, "/AlertRules/deactivate_api", token, %{ids: ids})
  end
end
