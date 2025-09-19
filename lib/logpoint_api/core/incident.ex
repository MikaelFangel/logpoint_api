defmodule LogpointApi.Core.Incident do
  @moduledoc false
  alias LogpointApi.Net.SearchIncidentClient

  @version "0.1"

  def list_incidents(req, credential, start_time, end_time, opts \\ []) do
    body = create_request(%{version: @version, ts_from: start_time, ts_to: end_time})

    if Keyword.get(opts, :state) do
      SearchIncidentClient.get(req, "/incidents_states", credential, body)
    else
      SearchIncidentClient.get(req, "/incidents", credential, body)
    end
  end

  def get_incident_by_ids(req, credential, obj_id, incident_id) do
    body = create_request(%{incident_obj_id: obj_id, incident_id: incident_id})
    SearchIncidentClient.get(req, "/get_data_from_incident", credential, body)
  end

  # TODO: check for better validation of comments
  def add_comments(req, credential, comments) do
    body = create_request(%{version: @version, states: comments})
    SearchIncidentClient.post_json(req, "/add_incident_comment", credential, body)
  end

  def assign_incidents(req, credential, incident_ids, assignee) when is_list(incident_ids) do
    body = create_request(%{version: @version, incident_ids: incident_ids, new_assignee: assignee})
    SearchIncidentClient.post_json(req, "/assign_incident", credential, body)
  end

  def change_incident_status(req, credential, action, incident_ids)
      when action in [:resolve, :reopen, :close] and is_list(incident_ids) do
    endpoint =
      case action do
        :resolve -> "/resolve_incident"
        :reopen -> "/reopen_incident"
        :close -> "/close_incident"
      end

    body = create_request(%{version: @version, incident_ids: incident_ids})
    SearchIncidentClient.post_json(req, endpoint, credential, body)
  end

  @doc """
  Gets users from the Logpoint instance.
  """
  def get_users(req, credential) do
    SearchIncidentClient.get(req, "/get_users", credential)
  end

  defp create_request(params) do
    %{requestData: params}
  end
end
