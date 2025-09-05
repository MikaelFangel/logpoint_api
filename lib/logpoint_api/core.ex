defmodule LogpointApi.Core do
  @moduledoc false

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
    payload = build_payload(credentials, :query, %{"requestData" => Jason.encode!(request_data)})
    opts = [verify_ssl: Map.get(credentials, :verify_ssl, false)]
    make_request(credentials.ip, "/getsearchlogs", :post, payload, :urlencoded, opts)
  end

  @doc """
  Gets allowed data from the Logpoint instance.
  """
  @spec get_allowed_data(credentials(), atom()) :: {:ok, map()} | {:error, String.t()}
  def get_allowed_data(credentials, type) when type in @allowed_types do
    payload = build_payload(credentials, :query, %{"type" => Atom.to_string(type)})
    opts = [verify_ssl: Map.get(credentials, :verify_ssl, false)]
    make_request(credentials.ip, "/getalloweddata", :post, payload, :urlencoded, opts)
  end

  @doc """
  Gets users from the Logpoint instance.
  """
  @spec get_users(credentials()) :: {:ok, map()} | {:error, String.t()}
  def get_users(credentials) do
    payload = build_payload(credentials, :json)
    opts = [verify_ssl: Map.get(credentials, :verify_ssl, false)]
    make_request(credentials.ip, "/get_users", :get, payload, :json, opts)
  end

  @doc """
  Updates incident state via API call.
  """
  @spec update_incident_state(credentials(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  def update_incident_state(credentials, path, request_data) do
    payload = build_payload(credentials, :json, request_data)
    opts = [verify_ssl: Map.get(credentials, :verify_ssl, false)]
    make_request(credentials.ip, path, :post, payload, :json, opts)
  end

  @doc """
  Gets incident information via API call.
  """
  @spec get_incident_information(credentials(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  def get_incident_information(credentials, path, request_data) do
    payload = build_payload(credentials, :json, request_data)
    opts = [verify_ssl: Map.get(credentials, :verify_ssl, false)]
    make_request(credentials.ip, path, :get, payload, :json, opts)
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

  defp build_payload(credentials, format, request_data \\ nil) do
    base_payload = %{
      "username" => credentials.username,
      "secret_key" => credentials.secret_key
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

  defp make_request(ip, path, method, payload, content_type, opts) do
    url = "https://" <> ip <> path
    verify_ssl = Keyword.get(opts, :verify_ssl, false)

    headers =
      case content_type do
        :json -> [{"Content-Type", "application/json"}]
        :urlencoded -> [{"Content-Type", "application/x-www-form-urlencoded"}]
      end

    case HTTPoison.request(method, url, payload, headers, if(verify_ssl, do: [], else: [hackney: [:insecure]])) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        case Jason.decode(body) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, "Invalid JSON response"}
        end

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        error_msg =
          case Jason.decode(body) do
            {:ok, %{"error" => error}} -> "HTTP #{status}: #{error}"
            {:ok, parsed} when is_map(parsed) -> "HTTP #{status}: #{inspect(parsed)}"
            _ -> "HTTP #{status}: #{body}"
          end

        {:error, error_msg}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end
