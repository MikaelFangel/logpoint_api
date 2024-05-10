defmodule LogpointApi.IncidentApi do
  @moduledoc """
  This module provides an implementation of the Logpoint Incident API.
  """

  alias LogpointApi.Credential

  defmodule TimeRange do
    @typedoc """
    Struct representing a time range with timestamps in epoch.
    """
    @type t :: %__MODULE__{ts_from: Number.t(), ts_to: Number.t(), version: String.t()}
    @derive {Jason.Encoder, only: [:version, :ts_from, :ts_to]}
    defstruct [:ts_from, :ts_to, version: "0.1"]
  end

  defmodule Incident do
    @typedoc """
    Struct used to fetch an incident.
    """
    @type t :: %__MODULE__{incident_obj_id: String.t(), incident_id: String.t()}
    @derive {Jason.Encoder, only: [:incident_obj_id, :incident_id]}
    defstruct [:incident_obj_id, :incident_id]
  end

  defmodule IncidentComment do
    @typedoc """
    Struct to add comments to a particular incident.
    """
    @type t :: %__MODULE__{_id: String.t(), comments: list()}
    @derive {Jason.Encoder, only: [:_id, :comments]}
    defstruct _id: "", comments: []
  end

  defmodule IncidentCommentData do
    @typedoc """
    Struct to add comments to a list of incidents using the `IncidentComment` struct.
    """
    @type t :: %__MODULE__{version: String.t(), states: list()}
    @derive {Jason.Encoder, only: [:version, :states]}
    defstruct version: "0.1", states: [%IncidentComment{}]
  end

  defmodule IncidentIDs do
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
  @spec get_incidents(String.t(), Credential.t(), TimeRange.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_incidents(ip, credential, %TimeRange{} = time_range),
    do: get_incident_information(ip, "/incidents", credential, time_range)

  @doc """
  Get a specific incident and its related data.
  """
  @spec get_data_from_incident(String.t(), Credential.t(), Incident.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_data_from_incident(ip, credential, %Incident{} = incident),
    do: get_incident_information(ip, "/get_data_from_incident", credential, incident)

  @doc """
  Get the states of incidents within a specific time range.
  """
  @spec get_incident_states(String.t(), Credential.t(), TimeRange.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_incident_states(ip, credential, %TimeRange{} = time_range),
    do: get_incident_information(ip, "/incident_states", credential, time_range)

  @doc """
  Get users.
  """
  @spec get_users(String.t(), Credential.t()) :: {:ok, map()} | {:error, String.t()}
  def get_users(ip, credential) do
    payload = make_payload(credential)
    make_request(ip, "/get_users", :get, payload)
  end

  @doc """
  Add comments to a list of incidents.
  """
  @spec add_comments(String.t(), Credential.t(), IncidentCommentData.t()) ::
          {:ok, map()} | {:error, String.t()}
  def add_comments(ip, credential, %IncidentCommentData{} = incident_comment_data),
    do: update_incident_state(ip, "/add_incident_comment", credential, incident_comment_data)

  @doc """
  Assign or re-assign a list of incidents.
  """
  @spec assign_incidents(String.t(), Credential.t(), IncidentIDs.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def assign_incidents(ip, credential, %IncidentIDs{} = incident_ids, assignee_id) do
    payload = Map.put(incident_ids, :new_assignee, assignee_id)
    update_incident_state(ip, "/assign_incident", credential, payload)
  end

  @doc """
  Resolve a list of incidents.
  """
  @spec resolve_incidents(String.t(), Credential.t(), IncidentIDs.t()) ::
          {:ok, map()} | {:error, String.t()}
  def resolve_incidents(ip, credential, %IncidentIDs{} = incident_ids),
    do: update_incident_state(ip, "/resolve_incident", credential, incident_ids)

  @doc """
  Reopen a list of incidents.
  """
  @spec reopen_incidents(String.t(), Credential.t(), IncidentIDs.t()) ::
          {:ok, map()} | {:error, String.t()}
  def reopen_incidents(ip, credential, %IncidentIDs{} = incident_ids),
    do: update_incident_state(ip, "/reopen_incident", credential, incident_ids)

  @doc """
  Close a list of incidents.
  """
  @spec close_incidents(String.t(), Credential.t(), IncidentIDs.t()) ::
          {:ok, map()} | {:error, String.t()}
  def close_incidents(ip, credential, %IncidentIDs{} = incident_ids),
    do: update_incident_state(ip, "/close_incident", credential, incident_ids)

  @doc false
  @spec update_incident_state(String.t(), String.t(), Credential.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defp update_incident_state(ip, path, credential, request_data) do
    payload = make_payload(credential, request_data)
    make_request(ip, path, :post, payload)
  end

  @doc false
  @spec get_incident_information(String.t(), String.t(), Credential.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defp get_incident_information(ip, path, credential, request_data) do
    payload = make_payload(credential, request_data)
    make_request(ip, path, :get, payload)
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
  @spec make_payload(Credential.t(), map()) :: String.t()
  defp make_payload(%Credential{} = credential, request_data) do
    %{
      "username" => credential.username,
      "secret_key" => credential.secret_key,
      "requestData" => request_data
    }
    |> Jason.encode!()
  end

  @doc false
  @spec make_payload(Credential.t()) :: String.t()
  defp make_payload(%Credential{} = credential) do
    %{
      "username" => credential.username,
      "secret_key" => credential.secret_key
    }
    |> Jason.encode!()
  end
end
