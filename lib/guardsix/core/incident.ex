defmodule Guardsix.Core.Incident do
  @moduledoc """
  Manage incidents in Guardsix.

  Wraps the [Incident API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/incident-api)
  for listing, assigning, commenting on, and changing the state of incidents.
  """

  alias Guardsix.Data.Client
  alias Guardsix.Error
  alias Guardsix.Net.CredentialClient

  @version "0.1"

  @doc """
  List incidents within a time range.

  An optional `filters` map can be provided to filter by name, status, type,
  risk, attack_category, attack_tag, log_source, or custom metadata fields.
  Multiple values for a single filter can be comma-separated.

  ## Examples

      Incident.list(client, start_time, end_time)
      Incident.list(client, start_time, end_time, %{status: "unresolved", risk: "critical"})

  """
  @spec list(Client.t(), number(), number(), map()) :: {:ok, map()} | {:error, Error.t()}
  def list(%Client{} = client, start_time, end_time, filters \\ %{}) do
    body = request_data(%{version: @version, ts_from: start_time, ts_to: end_time})
    CredentialClient.get(req(client), build_path("/incidents", filters), client.credential, body)
  end

  @doc """
  List incident states within a time range.

  An optional `filters` map can be provided to filter by name, status, type,
  risk, attack_category, attack_tag, log_source, or custom metadata fields.
  Multiple values for a single filter can be comma-separated.

  Note: filter support for this endpoint is unverified and filters may be
  ignored by the API.

  ## Examples

      Incident.list_states(client, start_time, end_time)
      Incident.list_states(client, start_time, end_time, %{status: "unresolved"})

  """
  @spec list_states(Client.t(), number(), number(), map()) :: {:ok, map()} | {:error, Error.t()}
  def list_states(%Client{} = client, start_time, end_time, filters \\ %{}) do
    body = request_data(%{version: @version, ts_from: start_time, ts_to: end_time})
    CredentialClient.get(req(client), build_path("/incident_states", filters), client.credential, body)
  end

  @doc """
  Get incident data by object ID and incident ID.
  """
  @spec get(Client.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(%Client{} = client, obj_id, incident_id) do
    body = request_data(%{incident_obj_id: obj_id, incident_id: incident_id})
    CredentialClient.get(req(client), "/get_data_from_incident", client.credential, body)
  end

  @doc """
  Add comments to incidents.
  """
  @spec add_comments(Client.t(), list()) :: {:ok, map()} | {:error, Error.t()}
  def add_comments(%Client{} = client, comments) do
    body = request_data(%{version: @version, states: comments})
    CredentialClient.post_json(req(client), "/add_incident_comment", client.credential, body)
  end

  @doc """
  Assign incidents to a user.
  """
  @spec assign(Client.t(), [String.t()], String.t()) :: {:ok, map()} | {:error, Error.t()}
  def assign(%Client{} = client, incident_ids, assignee) when is_list(incident_ids) do
    body = request_data(%{version: @version, incident_ids: incident_ids, new_assignee: assignee})
    CredentialClient.post_json(req(client), "/assign_incident", client.credential, body)
  end

  for status_change <- ~w(resolve close reopen)a do
    @doc """
    #{status_change |> to_string() |> String.capitalize()} incidents.
    """
    @spec unquote(status_change)(Client.t(), [String.t()]) :: {:ok, map()} | {:error, Error.t()}
    def unquote(status_change)(%Client{} = client, incident_ids) when is_list(incident_ids) do
      change_status(client, "/#{unquote(status_change)}_incident", incident_ids)
    end
  end

  @doc """
  Get users from the Guardsix instance.
  """
  @spec get_users(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_users(%Client{} = client) do
    CredentialClient.get(req(client), "/get_users", client.credential)
  end

  defp build_path(base, filters) when map_size(filters) == 0, do: base
  defp build_path(base, filters), do: base <> "?" <> URI.encode_query(filters)

  defp change_status(%Client{} = client, endpoint, incident_ids) do
    body = request_data(%{version: @version, incident_ids: incident_ids})
    CredentialClient.post_json(req(client), endpoint, client.credential, body)
  end

  defp req(%Client{} = client) do
    CredentialClient.new(client.base_url, client.ssl_verify)
  end

  defp request_data(params) do
    %{requestData: params}
  end
end
