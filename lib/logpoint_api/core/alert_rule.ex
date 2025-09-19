defmodule LogpointApi.Core.AlertRule do
  @moduledoc false

  alias LogpointApi.Net.AlertRuleClient

  def list_alerts(req, token, params \\ %{}) do
    AlertRuleClient.get(req, "/AlertRules/lists_api", token, params)
  end
end
