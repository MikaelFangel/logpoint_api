defmodule LogpointApi do
  @moduledoc """
  Elixir library for interacting with the Logpoint API.

  This library provides a simple, stateless interface to the Logpoint API.
  All functions take credentials as parameters and make direct HTTP requests.

  ## Example Usage

  ```elixir
  # Create a Req client
  req = LogpointApi.Net.SearchIncidentClient.new("https://127.0.0.1")

  # Define credentials
  credentials = %LogpointApi.Data.Credential{
    username: "admin",
    secret_key: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  }

  # Create a query
  query = LogpointApi.Data.SearchParams.new(
    "user=*",
    "Last 24 hours",
    100,
    ["127.0.0.1"]
  )

  # Do it step by step
  {:ok, %{"search_id" => search_id}} = LogpointApi.get_search_id(req, credentials, query)
  {:ok, result} = LogpointApi.get_search_result(req, credentials, search_id)
  ```
  """

  alias LogpointApi.Core.Incident
  alias LogpointApi.Core.Search
  alias LogpointApi.Data.Credential
  alias LogpointApi.Data.SearchParams
  alias LogpointApi.Net.SearchIncidentClient

  @typedoc """
  Configured Req client for the Logpoint instance
  """
  @type req_client :: Req.Request.t()

  @typedoc """
  Credentials for authenticating with the Logpoint API.
  """
  @type credentials :: Credential.t()

  @doc """
  Create a search and get its search id.
  """
  @spec get_search_id(req_client(), credentials(), SearchParams.t()) ::
          {:ok, map()} | {:error, term()}
  def get_search_id(req, credentials, %SearchParams{} = query) do
    Search.get_search_logs(req, credentials, query)
  end

  @doc """
  Retrieve the search result of a specific search id.
  """
  @spec get_search_result(req_client(), credentials(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_search_result(req, credentials, search_id) when is_binary(search_id) do
    Search.get_search_logs(req, credentials, search_id)
  end

  @doc """
  Get user preferences from the Logpoint instance.
  """
  @spec user_preference(req_client(), credentials()) :: {:ok, map()} | {:error, term()}
  def user_preference(req, credentials) do
    Search.get_allowed_data(req, credentials, :user_preference)
  end

  @doc """
  Get loginspects from the Logpoint instance.
  """
  @spec loginspects(req_client(), credentials()) :: {:ok, map()} | {:error, term()}
  def loginspects(req, credentials) do
    Search.get_allowed_data(req, credentials, :loginspects)
  end

  @doc """
  Get logpoint repositories from the instance.
  """
  @spec logpoint_repos(req_client(), credentials()) :: {:ok, map()} | {:error, term()}
  def logpoint_repos(req, credentials) do
    Search.get_allowed_data(req, credentials, :logpoint_repos)
  end

  @doc """
  Get devices from the Logpoint instance.
  """
  @spec devices(req_client(), credentials()) :: {:ok, map()} | {:error, term()}
  def devices(req, credentials) do
    Search.get_allowed_data(req, credentials, :devices)
  end

  @doc """
  Get live searches from the Logpoint instance.
  """
  @spec livesearches(req_client(), credentials()) :: {:ok, map()} | {:error, term()}
  def livesearches(req, credentials) do
    Search.get_allowed_data(req, credentials, :livesearches)
  end

  @doc """
  Get users from the Logpoint instance.
  """
  @spec users(req_client(), credentials()) :: {:ok, map()} | {:error, term()}
  def users(req, credentials) do
    Incident.get_users(req, credentials)
  end

  @doc """
  Get incident information by object ID and incident ID.
  """
  @spec incident(req_client(), credentials(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def incident(req, credentials, incident_obj_id, incident_id) do
    Incident.get_incident_by_ids(req, credentials, incident_obj_id, incident_id)
  end

  @doc """
  Get incidents within a time range.
  """
  @spec incidents(req_client(), credentials(), number(), number()) ::
          {:ok, map()} | {:error, term()}
  def incidents(req, credentials, start_time, end_time) do
    Incident.list_incidents(req, credentials, start_time, end_time)
  end

  @doc """
  Get incident states within a time range.
  """
  @spec incident_states(req_client(), credentials(), number(), number()) ::
          {:ok, map()} | {:error, term()}
  def incident_states(req, credentials, start_time, end_time) do
    Incident.list_incidents(req, credentials, start_time, end_time, state: true)
  end

  @doc """
  Add comments to incidents.

  Accepts a list of LogpointApi.Data.Comment structs.
  """
  @spec add_comments(req_client(), credentials(), [LogpointApi.Data.Comment.t()]) ::
          {:ok, map()} | {:error, term()}
  def add_comments(req, credentials, comments) when is_list(comments) do
    Incident.add_comments(req, credentials, comments)
  end

  @doc """
  Assign incidents to a user.
  """
  @spec assign_incidents(req_client(), credentials(), [String.t()], String.t()) ::
          {:ok, map()} | {:error, term()}
  def assign_incidents(req, credentials, incident_ids, assignee_id)
      when is_list(incident_ids) and is_binary(assignee_id) do
    Incident.assign_incidents(req, credentials, incident_ids, assignee_id)
  end

  @doc """
  Resolve incidents.
  """
  @spec resolve_incidents(req_client(), credentials(), [String.t()]) ::
          {:ok, map()} | {:error, term()}
  def resolve_incidents(req, credentials, incident_ids) when is_list(incident_ids) do
    Incident.change_incident_status(req, credentials, :resolve, incident_ids)
  end

  @doc """
  Close incidents.
  """
  @spec close_incidents(req_client(), credentials(), [String.t()]) ::
          {:ok, map()} | {:error, term()}
  def close_incidents(req, credentials, incident_ids) when is_list(incident_ids) do
    Incident.change_incident_status(req, credentials, :close, incident_ids)
  end

  @doc """
  Reopen incidents.
  """
  @spec reopen_incidents(req_client(), credentials(), [String.t()]) ::
          {:ok, map()} | {:error, term()}
  def reopen_incidents(req, credentials, incident_ids) when is_list(incident_ids) do
    Incident.change_incident_status(req, credentials, :reopen, incident_ids)
  end
end
