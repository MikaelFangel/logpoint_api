defmodule LogpointApi.IncidentApi do
  @moduledoc """
  This module provides an implementation of the Logpoint Incident API.
  """

  alias LogpointApi.Client

  defmodule TimeRange do
    @moduledoc false
    @typedoc """
    Struct representing a time range with timestamps in epoch.
    """
    @type t :: %__MODULE__{ts_from: Number.t(), ts_to: Number.t(), version: String.t()}
    @derive {Jason.Encoder, only: [:version, :ts_from, :ts_to]}
    defstruct [:ts_from, :ts_to, version: "0.1"]
  end

  defmodule Incident do
    @moduledoc false
    @typedoc """
    Struct used to fetch an incident.
    """
    @type t :: %__MODULE__{incident_obj_id: String.t(), incident_id: String.t()}
    @derive {Jason.Encoder, only: [:incident_obj_id, :incident_id]}
    defstruct [:incident_obj_id, :incident_id]
  end

  defmodule IncidentComment do
    @moduledoc false
    @typedoc """
    Struct to add comments to a particular incident.
    """
    @type t :: %__MODULE__{_id: String.t(), comments: list()}
    @derive {Jason.Encoder, only: [:_id, :comments]}
    defstruct _id: "", comments: []
  end

  defmodule IncidentCommentData do
    @moduledoc false
    @typedoc """
    Struct to add comments to a list of incidents using the `IncidentComment` struct.
    """
    @type t :: %__MODULE__{version: String.t(), states: list()}
    @derive {Jason.Encoder, only: [:version, :states]}
    defstruct version: "0.1", states: [%IncidentComment{}]
  end

  defmodule IncidentIDs do
    @moduledoc false
    @typedoc """
    Struct that represents a list of incidents.
    """
    @type t :: %__MODULE__{version: String.t(), incident_ids: list()}
    @derive {Jason.Encoder, only: [:version, :incident_ids]}
    defstruct version: "0.1", incident_ids: []
  end

  @doc """
  Get all incidents within a given time range.
  """
  @spec get_incidents(Client.t(), TimeRange.t()) :: {:ok, map()} | {:error, String.t()}
  def get_incidents(client, %TimeRange{} = time_range),
    do: get_incident_information(client, "/incidents", time_range)

  @doc """
  Get a specific incident and its related data.
  """
  @spec get_data_from_incident(Client.t(), Incident.t()) :: {:ok, map()} | {:error, String.t()}
  def get_data_from_incident(client, %Incident{} = incident),
    do: get_incident_information(client, "/get_data_from_incident", incident)

  @doc """
  Get the states of incidents within a specific time range.
  """
  @spec get_incident_states(Client.t(), TimeRange.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_incident_states(client, %TimeRange{} = time_range),
    do: get_incident_information(client, "/incident_states", time_range)

  @doc """
  Get users.
  """
  @spec get_users(Client.t()) :: {:ok, map()} | {:error, String.t()}
  def get_users(client) do
    payload = make_payload(client)
    make_request(client.ip, "/get_users", :get, payload)
  end

  @doc """
  Add comments to a list of incidents.
  """
  @spec add_comments(Client.t(), IncidentCommentData.t()) :: {:ok, map()} | {:error, String.t()}
  def add_comments(client, %IncidentCommentData{} = incident_comment_data),
    do: update_incident_state(client, "/add_incident_comment", incident_comment_data)

  @doc """
  Assign or re-assign a list of incidents.
  """
  @spec assign_incidents(Client.t(), IncidentIDs.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def assign_incidents(client, %IncidentIDs{} = incident_ids, assignee_id) do
    payload = Map.put(incident_ids, :new_assignee, assignee_id)
    update_incident_state(client, "/assign_incident", payload)
  end

  @doc """
  Resolve a list of incidents.
  """
  @spec resolve_incidents(Client.t(), IncidentIDs.t()) :: {:ok, map()} | {:error, String.t()}
  def resolve_incidents(client, %IncidentIDs{} = incident_ids),
    do: update_incident_state(client, "/resolve_incident", incident_ids)

  @doc """
  Reopen a list of incidents.
  """
  @spec reopen_incidents(Client.t(), IncidentIDs.t()) :: {:ok, map()} | {:error, String.t()}
  def reopen_incidents(client, %IncidentIDs{} = incident_ids),
    do: update_incident_state(client, "/reopen_incident", incident_ids)

  @doc """
  Close a list of incidents.
  """
  @spec close_incidents(Client.t(), IncidentIDs.t()) ::
          {:ok, map()} | {:error, String.t()}
  def close_incidents(client, %IncidentIDs{} = incident_ids),
    do: update_incident_state(client, "/close_incident", incident_ids)

  @doc false
  @spec update_incident_state(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defp update_incident_state(client, path, request_data) do
    payload = make_payload(client, request_data)
    make_request(client.ip, path, :post, payload)
  end

  @doc false
  @spec get_incident_information(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defp get_incident_information(client, path, request_data) do
    payload = make_payload(client, request_data)
    make_request(client.ip, path, :get, payload)
  end

  @doc false
  @spec make_request(String.t(), String.t(), atom(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  defp make_request(ip, path, method, payload) do
    url = build_url(ip, path)
    headers = [{"Content-Type", "application/json"}]
    # On-prem uses self signed certificates and we thus need to disable the verification.
    options = [ssl: [{:verify, :verify_none}]]

    case HTTPoison.request(method, url, payload, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received response with status code #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed with reason: #{reason}"}
    end
  end

  @doc false
  @spec build_url(String.t(), String.t()) :: String.t()
  defp build_url(ip, path), do: "https://" <> ip <> path

  @doc false
  @spec make_payload(Client.t(), map()) :: String.t()
  defp make_payload(%Client{} = client, request_data) do
    %{
      "username" => client.username,
      "secret_key" => client.secret_key,
      "requestData" => request_data
    }
    |> Jason.encode!()
  end

  @doc false
  @spec make_payload(Client.t()) :: String.t()
  defp make_payload(%Client{} = client) do
    %{
      "username" => client.username,
      "secret_key" => client.secret_key
    }
    |> Jason.encode!()
  end
end
