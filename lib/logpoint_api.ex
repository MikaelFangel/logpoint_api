defmodule LogpointApi do
  @moduledoc """
  Elixir library for interacting with the Logpoint API.

  This library provides a simple, stateless interface to the Logpoint API.
  All functions take credentials as parameters and make direct HTTP requests.

  ## Example Usage

  ```elixir
  # Define credentials
  credentials = LogpointApi.Credentials.new(
    "127.0.0.1",
    "admin",
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    false  # verify_ssl, optional, defaults to true
  )

  # Create a query
  query = %LogpointApi.Query{
    query: "user=*",
    limit: 100,
    repos: ["127.0.0.1:5504"],
    time_range: [1_714_986_600, 1_715_031_000]
  }

  # Run a complete search (get search_id + poll for results)
  {:ok, result} = LogpointApi.run_search(credentials, query)

  # Or do it step by step
  {:ok, %{"search_id" => search_id}} = LogpointApi.get_search_id(credentials, query)
  {:ok, result} = LogpointApi.get_search_result(credentials, search_id)
  ```
  """

  alias LogpointApi.Core
  alias LogpointApi.Credentials
  alias LogpointApi.Incident
  alias LogpointApi.IncidentComment
  alias LogpointApi.IncidentCommentData
  alias LogpointApi.IncidentIDs
  alias LogpointApi.Query
  alias LogpointApi.TimeRange

  @typedoc """
  Credentials for authenticating with the Logpoint API.
  """
  @type credentials :: Credentials.t()

  @doc """
  Run a complete search: submit query, poll for completion, and return results.

  This is a convenience function that combines `get_search_id/2` and `get_search_result/2`
  with automatic polling until the search completes.
  """
  @spec run_search(Credentials.t(), Query.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def run_search(credentials, %Query{} = query, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 1000)
    max_retries = Keyword.get(opts, :max_retries, 60)

    with {:ok, %{"search_id" => search_id}} <- get_search_id(credentials, query) do
      Core.poll_search_result(credentials, search_id, poll_interval, max_retries, query)
    end
  end

  @doc """
  Create a search and get its search id.
  """
  @spec get_search_id(Credentials.t(), Query.t()) :: {:ok, map()} | {:error, String.t()}
  def get_search_id(credentials, %Query{} = query), do: Core.get_search_logs(credentials, query)

  @doc """
  Retrieve the search result of a specific search id.
  """
  @spec get_search_result(Credentials.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_search_result(credentials, search_id), do: Core.get_search_logs(credentials, %{search_id: search_id})

  @doc """
  Get user preferences from the Logpoint instance.
  """
  @spec user_preference(Credentials.t()) :: {:ok, map()} | {:error, String.t()}
  def user_preference(credentials), do: Core.get_allowed_data(credentials, :user_preference)

  @doc """
  Get loginspects from the Logpoint instance.
  """
  @spec loginspects(Credentials.t()) :: {:ok, map()} | {:error, String.t()}
  def loginspects(credentials), do: Core.get_allowed_data(credentials, :loginspects)

  @doc """
  Get logpoint repositories from the instance.
  """
  @spec logpoint_repos(Credentials.t()) :: {:ok, map()} | {:error, String.t()}
  def logpoint_repos(credentials), do: Core.get_allowed_data(credentials, :logpoint_repos)

  @doc """
  Get devices from the Logpoint instance.
  """
  @spec devices(Credentials.t()) :: {:ok, map()} | {:error, String.t()}
  def devices(credentials), do: Core.get_allowed_data(credentials, :devices)

  @doc """
  Get live searches from the Logpoint instance.
  """
  @spec livesearches(Credentials.t()) :: {:ok, map()} | {:error, String.t()}
  def livesearches(credentials), do: Core.get_allowed_data(credentials, :livesearches)

  @doc """
  Get users from the Logpoint instance.
  """
  @spec users(Credentials.t()) :: {:ok, map()} | {:error, String.t()}
  def users(credentials), do: Core.get_users(credentials)

  @doc """
  Get a specific incident and its related data.
  """
  @spec get_data_from_incident(Credentials.t(), Incident.t()) :: {:ok, map()} | {:error, String.t()}
  def get_data_from_incident(credentials, %Incident{} = incident) do
    Core.get_incident_info(credentials, incident)
  end

  @doc """
  Get incident information by object ID and incident ID.
  """
  @spec incident(Credentials.t(), String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def incident(credentials, incident_obj_id, incident_id) do
    incident = Incident.new(incident_obj_id, incident_id)
    Core.get_incident_info(credentials, incident)
  end

  @doc """
  Get incidents within a time range.
  """
  @spec incidents(Credentials.t(), number(), number()) :: {:ok, map()} | {:error, String.t()}
  def incidents(credentials, start_time, end_time) do
    time_range = TimeRange.new(start_time, end_time)
    Core.get_incident_info(credentials, :incidents, time_range)
  end

  @doc """
  Get incident states within a time range.
  """
  @spec incident_states(Credentials.t(), number(), number()) :: {:ok, map()} | {:error, String.t()}
  def incident_states(credentials, start_time, end_time) do
    time_range = TimeRange.new(start_time, end_time)
    Core.get_incident_info(credentials, :incident_states, time_range)
  end

  @doc """
  Add comments to incidents.

  Accepts either a map of %{"incident_id" => ["comment1", "comment2"]}
  or an IncidentCommentData struct.
  """
  @spec add_comments(Credentials.t(), map() | IncidentCommentData.t()) :: {:ok, map()} | {:error, String.t()}
  def add_comments(credentials, %IncidentCommentData{} = incident_comment_data),
    do: Core.update_incident_state(credentials, "/add_incident_comment", incident_comment_data)

  def add_comments(credentials, comments) when is_map(comments) and not is_struct(comments) do
    comment_structs =
      Enum.map(comments, fn {incident_id, comment_list} ->
        IncidentComment.new(incident_id, comment_list)
      end)

    comment_data = IncidentCommentData.new("0.1", comment_structs)
    add_comments(credentials, comment_data)
  end

  @doc """
  Assign incidents to a user.

  Accepts either a list of incident IDs or an IncidentIDs struct.
  """
  @spec assign_incidents(Credentials.t(), [String.t()] | IncidentIDs.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def assign_incidents(credentials, %IncidentIDs{} = incident_ids, assignee_id) do
    payload = Map.put(incident_ids, :new_assignee, assignee_id)
    Core.update_incident_state(credentials, "/assign_incident", payload)
  end

  def assign_incidents(credentials, incident_ids, assignee_id) when is_list(incident_ids) do
    incident_ids_struct = IncidentIDs.new("0.1", incident_ids)
    assign_incidents(credentials, incident_ids_struct, assignee_id)
  end

  @doc """
  Resolve incidents.
  """
  @spec resolve_incidents(Credentials.t(), [String.t()]) :: {:ok, map()} | {:error, String.t()}
  def resolve_incidents(credentials, incident_ids) do
    incident_ids_struct = IncidentIDs.new("0.1", incident_ids)
    Core.update_incidents(credentials, :resolve, incident_ids_struct)
  end

  @doc """
  Close incidents.
  """
  @spec close_incidents(Credentials.t(), [String.t()]) :: {:ok, map()} | {:error, String.t()}
  def close_incidents(credentials, incident_ids) do
    incident_ids_struct = IncidentIDs.new("0.1", incident_ids)
    Core.update_incidents(credentials, :close, incident_ids_struct)
  end

  @doc """
  Reopen incidents.
  """
  @spec reopen_incidents(Credentials.t(), [String.t()]) :: {:ok, map()} | {:error, String.t()}
  def reopen_incidents(credentials, incident_ids) do
    incident_ids_struct = IncidentIDs.new("0.1", incident_ids)
    Core.update_incidents(credentials, :reopen, incident_ids_struct)
  end
end
