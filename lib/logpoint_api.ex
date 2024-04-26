defmodule LogpointApi do
  defmodule Credential do
    defstruct [:username, :secret_key]
  end
end

defmodule LogpointApi.SearchApi do
  alias LogpointApi.Credential, as: Credential

  @allowed_types ["user_preference", "loginspects", "Logpoint_repos", "devices", "livesearches"]

  defmodule Query do
    @derive {Jason.Encoder, only: [:query, :time_range, :limit, :repos]}
    defstruct [:query, :time_range, :limit, :repos]
  end

  defmodule SearchID do
    @derive {Jason.Encoder, only: [:search_id]}
    defstruct [:search_id]
  end

  def get_user_timezone(ip, %Credential{} = credential),
    do: get_allowed_data(ip, %Credential{} = credential, "user_preference")

  def get_logpoints(ip, %Credential{} = credential),
    do: get_allowed_data(ip, %Credential{} = credential, "loginspects")

  def get_repos(ip, %Credential{} = credential),
    do: get_allowed_data(ip, %Credential{} = credential, "Logpoint_repos")

  def get_devices(ip, %Credential{} = credential),
    do: get_allowed_data(ip, %Credential{} = credential, "devices")

  def get_livesearches(ip, %Credential{} = credential),
    do: get_allowed_data(ip, %Credential{} = credential, "livesearches")

  def get_search_id(ip, %Credential{} = credential, %Query{} = request_data),
    do: get_search_logs(ip, %Credential{} = credential, request_data)

  def get_search_result(ip, %Credential{} = credential, %SearchID{} = request_data),
    do: get_search_logs(ip, %Credential{} = credential, request_data)

  defp make_request(ip, path, payload) do
    url = "https://" <> ip <> path
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    # On-prem uses self signed certificates and we thus need to disable the verification.
    options = [ssl: [{:verify, :verify_none}]]

    case HTTPoison.post(url, payload, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode!()

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Received response with status code #{status_code}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("HTTP request failed with reason: #{reason}")
    end
  end

  defp get_allowed_data(ip, %Credential{} = credential, type) when type in @allowed_types do
    payload =
      URI.encode_query(%{
        "username" => credential.username,
        "secret_key" => credential.secret_key,
        "type" => type
      })

    make_request(ip, "/getalloweddata", payload)
  end

  defp get_search_logs(ip, %Credential{} = credential, request_data) do
    payload =
      URI.encode_query(%{
        "username" => credential.username,
        "secret_key" => credential.secret_key,
        "requestData" => request_data |> Jason.encode!()
      })

    make_request(ip, "/getsearchlogs", payload)
  end
end

defmodule LogpointApi.IncidentApi do
  defp make_request(ip, path, params) do
    url = "https://" <> ip <> path
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(params)
    # On-prem uses self signed certificates and we thus need to disable the verification.
    options = [ssl: [{:verify, :verify_none}]]

    case HTTPoison.request(:get, url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode!()

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Received response with status code #{status_code}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("HTTP request failed with reason: #{reason}")
    end
  end
end
