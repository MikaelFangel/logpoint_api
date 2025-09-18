defmodule LogpointApi.Core do
  @moduledoc false

  alias LogpointApi.ApiClient
  alias LogpointApi.ApiClient.LegacyAuth
  alias LogpointApi.Query

  @allowed_types [:user_preference, :loginspects, :logpoint_repos, :devices, :livesearches]

  @typedoc """
  Credentials for authenticating with the Logpoint API.
  """
  @type credentials :: %{
          ip: String.t(),
          username: String.t(),
          secret_key: String.t(),
          verify_ssl: boolean()
        }

  @doc """
  Performs search log operations (both search creation and result retrieval).
  """
  @spec get_search_logs(credentials(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_search_logs(credentials, request_data) do
    auth = build_legacy_auth(credentials)
    url = build_url(credentials.ip, "/getsearchlogs")

    # The search API expects requestData to be JSON-encoded in the query params
    encoded_request_data = %{"requestData" => Jason.encode!(request_data)}

    case ApiClient.post(url, encoded_request_data, auth, :urlencoded) do
      {:ok, result} -> {:ok, result}
      {:error, {:http_error, status, body}} -> format_error(status, body)
      {:error, reason} -> {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets allowed data from the Logpoint instance.
  """
  @spec get_allowed_data(credentials(), atom()) :: {:ok, map()} | {:error, String.t()}
  def get_allowed_data(credentials, type) when type in @allowed_types do
    auth = build_legacy_auth(credentials)
    url = build_url(credentials.ip, "/getalloweddata")

    case ApiClient.post(url, %{"type" => Atom.to_string(type)}, auth, :urlencoded) do
      {:ok, result} -> {:ok, result}
      {:error, {:http_error, status, body}} -> format_error(status, body)
      {:error, reason} -> {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets users from the Logpoint instance.
  """
  @spec get_users(credentials()) :: {:ok, map()} | {:error, String.t()}
  def get_users(credentials) do
    auth = build_legacy_auth(credentials)
    url = build_url(credentials.ip, "/get_users")

    case ApiClient.get(url, auth) do
      {:ok, result} -> {:ok, result}
      {:error, {:http_error, status, body}} -> format_error(status, body)
      {:error, reason} -> {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Updates incident state via API call.
  """
  @spec update_incident_state(credentials(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  def update_incident_state(credentials, path, request_data) do
    auth = build_legacy_auth(credentials)
    url = build_url(credentials.ip, path)

    case ApiClient.post(url, request_data, auth, :json) do
      {:ok, result} -> {:ok, result}
      {:error, {:http_error, status, body}} -> format_error(status, body)
      {:error, reason} -> {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets incident information via API call.
  """
  @spec get_incident_information(credentials(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  def get_incident_information(credentials, path, request_data) do
    auth = build_legacy_auth(credentials)
    url = build_url(credentials.ip, path)

    case ApiClient.get(url, auth, Jason.decode!(Jason.encode!(request_data))) do
      {:ok, result} -> {:ok, result}
      {:error, {:http_error, status, body}} -> format_error(status, body)
      {:error, reason} -> {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Polls search results until completion or timeout.
  """
  @spec poll_search_result(credentials(), String.t(), pos_integer(), pos_integer(), Query.t()) ::
          {:ok, map()} | {:error, String.t()}
  def poll_search_result(credentials, search_id, poll_interval, max_retries, query) do
    do_poll_search_result(credentials, search_id, poll_interval, max_retries, query, 0)
  end

  @doc """
  Gets specific incident info by struct.
  """
  @spec get_incident_info(credentials(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_incident_info(credentials, %{__struct__: LogpointApi.Incident} = incident) do
    get_incident_information(credentials, "/get_data_from_incident", incident)
  end

  @doc """
  Gets incident info by action and time range.
  """
  @spec get_incident_info(credentials(), atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_incident_info(credentials, action, %{__struct__: LogpointApi.TimeRange} = time_range) do
    endpoint =
      case action do
        :incidents -> "/incidents"
        :incident_states -> "/incident_states"
      end

    get_incident_information(credentials, endpoint, time_range)
  end

  @doc """
  Updates incidents with specific action.
  """
  @spec update_incidents(credentials(), atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def update_incidents(credentials, action, %{__struct__: LogpointApi.IncidentIDs} = incident_ids) do
    endpoint =
      case action do
        :resolve -> "/resolve_incident"
        :reopen -> "/reopen_incident"
        :close -> "/close_incident"
      end

    update_incident_state(credentials, endpoint, incident_ids)
  end

  defp do_poll_search_result(_credentials, _search_id, _poll_interval, max_retries, _query, retries)
       when retries >= max_retries do
    {:error, "Search polling timeout after #{max_retries} retries"}
  end

  defp do_poll_search_result(credentials, search_id, poll_interval, max_retries, query, retries) do
    case get_search_logs(credentials, %{search_id: search_id}) do
      {:ok, %{"final" => true} = result} ->
        {:ok, result}

      {:ok, %{"final" => false}} ->
        :timer.sleep(poll_interval)
        do_poll_search_result(credentials, search_id, poll_interval, max_retries, query, retries + 1)

      {:ok, %{"success" => false}} ->
        case get_search_logs(credentials, query) do
          {:ok, %{"search_id" => new_search_id}} ->
            do_poll_search_result(credentials, new_search_id, poll_interval, max_retries, query, retries + 1)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_legacy_auth(credentials) do
    %LegacyAuth{
      username: credentials.username,
      secret_key: credentials.secret_key
    }
  end

  defp build_url(ip, path) do
    "https://#{ip}#{path}"
  end

  defp format_error(status, body) do
    error_msg =
      case body do
        %{"error" => error} -> "HTTP #{status}: #{error}"
        parsed when is_map(parsed) -> "HTTP #{status}: #{inspect(parsed)}"
        binary -> "HTTP #{status}: #{binary}"
      end

    {:error, error_msg}
  end
end
