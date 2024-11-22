defmodule LogpointApi do
  @moduledoc """
  This module provides an implementation of the Logpoint Incident API.
  """

  alias LogpointApi.Client

  @allowed_types [:user_preference, :loginspects, :logpoint_repos, :devices, :livesearches]

  defmodule Client do
    @moduledoc false
    @typedoc """
    Struct representing credentials used for authorization.
    """
    @type t :: %__MODULE__{ip: String.t(), username: String.t(), secret_key: String.t()}
    defstruct [:ip, :username, :secret_key]

    @spec new(String.t(), String.t(), String.t()) :: t()
    def new(ip, username, secret_key) do
      %__MODULE__{ip: ip, username: username, secret_key: secret_key}
    end
  end

  defmodule Query do
    @moduledoc false
    @typedoc """
    Struct representing a Logpoint search query.
    """
    @type t :: %__MODULE__{
            query: String.t(),
            time_range: list() | String.t(),
            limit: non_neg_integer(),
            repos: list()
          }
    @derive {Jason.Encoder, only: [:query, :time_range, :limit, :repos]}
    defstruct [:query, :time_range, :limit, :repos]

    @spec new(String.t(), list() | String.t(), non_neg_integer(), list()) :: t()
    def new(query, time_range, limit, repos) do
      %__MODULE__{
        query: query,
        time_range: time_range,
        limit: limit,
        repos: repos
      }
    end
  end

  defmodule TimeRange do
    @moduledoc false
    @typedoc """
    Struct representing a time range with timestamps in epoch.
    """
    @type t :: %__MODULE__{ts_from: Number.t(), ts_to: Number.t(), version: String.t()}
    @derive {Jason.Encoder, only: [:version, :ts_from, :ts_to]}
    defstruct [:ts_from, :ts_to, version: "0.1"]

    @spec new(number(), number(), String.t()) :: t()
    def new(ts_from, ts_to, version \\ "0.1") do
      %__MODULE__{ts_from: ts_from, ts_to: ts_to, version: version}
    end
  end

  defmodule Incident do
    @moduledoc false
    @typedoc """
    Struct used to fetch an incident.
    """
    @type t :: %__MODULE__{incident_obj_id: String.t(), incident_id: String.t()}
    @derive {Jason.Encoder, only: [:incident_obj_id, :incident_id]}
    defstruct [:incident_obj_id, :incident_id]

    @spec new(String.t(), String.t()) :: t()
    def new(incident_obj_id, incident_id) do
      %__MODULE__{incident_obj_id: incident_obj_id, incident_id: incident_id}
    end
  end

  defmodule IncidentComment do
    @moduledoc false
    @typedoc """
    Struct to add comments to a particular incident.
    """
    @type t :: %__MODULE__{_id: String.t(), comments: list()}
    @derive {Jason.Encoder, only: [:_id, :comments]}
    defstruct _id: "", comments: []

    @spec new(String.t(), [String.t()]) :: t()
    def new(id, comments \\ []) do
      %__MODULE__{_id: id, comments: comments}
    end
  end

  defmodule IncidentCommentData do
    @moduledoc false
    @typedoc """
    Struct to add comments to a list of incidents using the `IncidentComment` struct.
    """
    @type t :: %__MODULE__{version: String.t(), states: list()}
    @derive {Jason.Encoder, only: [:version, :states]}
    defstruct version: "0.1", states: [%IncidentComment{}]

    @spec new(String.t(), [IncidentComment.t()]) :: t()
    def new(version \\ "0.1", states \\ [%IncidentComment{}]) do
      %__MODULE__{version: version, states: states}
    end
  end

  defmodule IncidentIDs do
    @moduledoc false
    @typedoc """
    Struct that represents a list of incidents.
    """
    @type t :: %__MODULE__{version: String.t(), incident_ids: list()}
    @derive {Jason.Encoder, only: [:version, :incident_ids]}
    defstruct version: "0.1", incident_ids: []

    @spec new(String.t(), [String.t()]) :: t()
    def new(version \\ "0.1", incident_ids \\ []) do
      %__MODULE__{version: version, incident_ids: incident_ids}
    end
  end

  @doc """
  Create a search and get its search id.
  """
  @spec get_search_id(Client.t(), Query.t()) :: {:ok, map()} | {:error, String.t()}
  def get_search_id(client, %Query{} = query),
    do: get_search_logs(client, query)

  @doc """
  Retrieve the search result of a specific search id.
  """
  @spec get_search_result(Client.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_search_result(client, search_id),
    do: get_search_logs(client, %{search_id: search_id})

  @doc """
  Userd to get data about a Logppoint instance.
  """
  @spec get_allowed_data(Client.t(), atom()) :: {:ok, map()} | {:error, String.t()}
  def get_allowed_data(client, type) when type in @allowed_types do
    payload = build_payload(client, :query, %{"type" => Atom.to_string(type)})
    make_request(client.ip, "/getalloweddata", :post, payload, :urlencoded)
  end

  @doc false
  @spec get_search_logs(Client.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defp get_search_logs(client, request_data) do
    payload = build_payload(client, :query, %{"requestData" => Jason.encode!(request_data)})
    make_request(client.ip, "/getsearchlogs", :post, payload, :urlencoded)
  end

  @doc """
  Get a specific incident and its related data.
  """
  @spec get_incident_info(Client.t(), Incident.t()) :: {:ok, map()} | {:error, String.t()}
  def get_incident_info(client, %Incident{} = incident),
    do: get_incident_information(client, "/get_data_from_incident", incident)

  @doc """
  Get the informations about incidents within a time range.
  """
  @spec get_incident_info(Client.t(), :incidents | :incident_states, TimeRange.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_incident_info(client, action, %TimeRange{} = time_range) do
    endpoint =
      case action do
        :incidents -> "/incidents"
        :incident_states -> "/incident_states"
      end

    get_incident_information(client, endpoint, time_range)
  end

  @doc """
  Get users.
  """
  @spec get_users(Client.t()) :: {:ok, map()} | {:error, String.t()}
  def get_users(client) do
    payload = build_payload(client, :json)
    make_request(client.ip, "/get_users", :get, payload, :json)
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
  Update the state of a list of incidents.
  """
  @spec update_incidents(Client.t(), :resolve | :reopen | :close, IncidentIDs.t()) ::
          {:ok, map()} | {:error, String.t()}
  def update_incidents(client, action, %IncidentIDs{} = incident_ids) do
    endpoint =
      case action do
        :resolve -> "/resolve_incident"
        :reopen -> "/reopen_incident"
        :close -> "/close_incident"
      end

    update_incident_state(client, endpoint, incident_ids)
  end

  @spec update_incident_state(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defp update_incident_state(client, path, request_data) do
    payload = build_payload(client, :json, request_data)
    make_request(client.ip, path, :post, payload, :json)
  end

  @spec get_incident_information(Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defp get_incident_information(client, path, request_data) do
    payload = build_payload(client, :json, request_data)
    make_request(client.ip, path, :get, payload, :json)
  end

  @spec build_payload(Client.t(), :query | :json, map() | nil) :: String.t()
  defp build_payload(%Client{} = client, format, request_data \\ nil) do
    base_payload = %{
      "username" => client.username,
      "secret_key" => client.secret_key
    }

    payload =
      case {format, request_data} do
        {:query, data} -> Map.merge(base_payload, data)
        {:json, nil} -> base_payload
        {:json, data} -> Map.put(base_payload, "requestData", data)
      end

    case format do
      :query -> URI.encode_query(payload)
      :json -> Jason.encode!(payload)
    end
  end

  @spec make_request(String.t(), String.t(), atom(), String.t(), :json | :urlencoded) ::
          {:ok, map()} | {:error, String.t()}
  defp make_request(ip, path, method, payload, content_type) do
    url = "https://" <> ip <> path

    headers =
      case content_type do
        :json -> [{"Content-Type", "application/json"}]
        :urlencoded -> [{"Content-Type", "application/x-www-form-urlencoded"}]
      end

    # Set options to ignore SSL verification and set an infinite receive timeout
    options = [ssl: [{:verify, :verify_none}], recv_timeout: :infinity]

    case HTTPoison.request(method, url, payload, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received response with status code #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed with reason: #{reason}"}
    end
  end
end
