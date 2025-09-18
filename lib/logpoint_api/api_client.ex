defmodule LogpointApi.ApiClient do
  @moduledoc """
  """

  defmodule JWTAuth do
    @moduledoc false
    @enforce_keys [:token]
    defstruct [:token]
  end

  defmodule LegacyAuth do
    @moduledoc false
    @enforce_keys [:username, :secret_key]
    defstruct [:username, :secret_key]
  end

  @default_opts [hackney: [:insecure], recv_timeout: :infinity]

  def get(url, auth, params \\ %{})

  def get(url, %JWTAuth{token: token}, params) do
    full_url = build_url_with_params(url, params)
    headers = [{"Authorization", "Bearer " <> token}]

    full_url
    |> HTTPoison.get(headers, @default_opts)
    |> handle_response()
  end

  def get(url, %LegacyAuth{} = auth, params) do
    query_params = build_legacy_params(auth, params)
    full_url = build_url_with_params(url, query_params)

    full_url
    |> HTTPoison.get([], @default_opts)
    |> handle_response()
  end

  def post(url, body, %JWTAuth{token: token}) do
    json_body = encode_json(body)

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer " <> token}
    ]

    url
    |> HTTPoison.post(json_body, headers, @default_opts)
    |> handle_response()
  end

  def post(url, body, %LegacyAuth{} = auth, content_type \\ :json) do
    {encoded_body, headers} = prepare_legacy_post(auth, body, content_type)

    url
    |> HTTPoison.post(encoded_body, headers, @default_opts)
    |> handle_response()
  end

  defp build_url_with_params(url, params) when params == %{} or params == [], do: url

  defp build_url_with_params(url, params) do
    query_string = URI.encode_query(params)
    "#{url}?#{query_string}"
  end

  defp build_legacy_params(%LegacyAuth{username: username, secret_key: secret}, additional_params) do
    base_params = %{"username" => username, "secret_key" => secret}
    Map.merge(base_params, additional_params)
  end

  defp prepare_legacy_post(%LegacyAuth{} = auth, body, content_type) do
    case content_type do
      :json ->
        payload = build_legacy_json_payload(auth, body)
        encoded = encode_json(payload)
        headers = [{"Content-Type", "application/json"}]
        {encoded, headers}

      :urlencoded ->
        payload = build_legacy_params(auth, body)
        encoded = URI.encode_query(payload)
        headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
        {encoded, headers}
    end
  end

  defp build_legacy_json_payload(%LegacyAuth{username: username, secret_key: secret}, request_data) do
    base = %{"username" => username, "secret_key" => secret}

    case request_data do
      nil -> base
      data -> Map.put(base, "requestData", data)
    end
  end

  defp encode_json(data) when is_binary(data), do: data
  defp encode_json(data), do: Jason.encode!(data)

  defp handle_response({:ok, %HTTPoison.Response{status_code: status, body: body}}) when status in 200..299 do
    {:ok, maybe_decode(body)}
  end

  defp handle_response({:ok, %HTTPoison.Response{status_code: status, body: body}}) do
    {:error, {:http_error, status, maybe_decode(body)}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end

  defp maybe_decode(msg) when is_binary(msg) do
    case Jason.decode(msg) do
      {:ok, decoded} -> decoded
      {:error, _} -> msg
    end
  end
end
