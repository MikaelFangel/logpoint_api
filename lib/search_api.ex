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

  def get_user_timezone(ip, credential),
    do: get_allowed_data(ip, credential, "user_preference")

  def get_logpoints(ip, credential),
    do: get_allowed_data(ip, credential, "loginspects")

  def get_repos(ip, credential),
    do: get_allowed_data(ip, credential, "Logpoint_repos")

  def get_devices(ip, credential),
    do: get_allowed_data(ip, credential, "devices")

  def get_livesearches(ip, credential),
    do: get_allowed_data(ip, credential, "livesearches")

  def get_search_id(ip, credential, %Query{} = query),
    do: get_search_logs(ip, credential, query)

  def get_search_result(ip, credential, %SearchID{} = search_id),
    do: get_search_logs(ip, credential, search_id)

  defp make_request(ip, path, payload) do
    url = build_url(ip, path)
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    # On-prem uses self signed certificates and we thus need to disable the verification.
    options = [ssl: [{:verify, :verify_none}]]

    case HTTPoison.post(url, payload, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received response with status code #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed with reason: #{reason}"}
    end
  end

  defp build_url(ip, path), do: "https://" <> ip <> path

  defp get_allowed_data(ip, credential, type) when type in @allowed_types do
    payload = build_payload(credential, %{"type" => type})
    make_request(ip, "/getalloweddata", payload)
  end

  defp get_search_logs(ip, credential, request_data) do
    payload = build_payload(credential, %{"requestData" => Jason.encode!(request_data)})
    make_request(ip, "/getsearchlogs", payload)
  end

  defp build_payload(%Credential{} = credential, data) do
    Map.merge(
      %{
        "username" => credential.username,
        "secret_key" => credential.secret_key
      },
      data
    )
    |> URI.encode_query()
  end
end
