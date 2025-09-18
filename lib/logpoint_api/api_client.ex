defmodule LogpointApi.ApiClient do
  @moduledoc false

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

  def get_request(url, %JWTAuth{token: token}, params \\ %{}) do
    full_url = build_url_with_params(url, params)
    headers = [{"Authorization", "Bearer " <> token}]

    case HTTPoison.get(full_url, headers, hackney: [:insecure], recv_timeout: :infinity) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, maybe_decode(body)}

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, {:http_error, status, maybe_decode(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_request(url, %LegacyAuth{username: username, secret_key: secret}, content_type) do
    headers = [{"Content-Type", "application/json"}]
  end

  def post_requst(url, %LegacyAuth{username: username, secret_key: secret_key}, content_type) do
    # The search api get allowed data uses x-www encoding for its post requests
    headers =
      case content_type do
        :json -> [{"Content-Type", "application/json"}]
        :urlencoded -> [{"Content-Type", "application/x-www-form-urlencoded"}]
        _ -> []
      end
  end

  def post_request(url, body, %JWTAuth{token: token}) do
    HTTPoison.post(url, body, [{"Content-Type", "application/json", "Authorization", "Bearer " <> token}],
      hackney: [:insecure],
      recv_timeout: :infinity
    )
  end

  defp build_url_with_params(url, params) when params == %{} or params == [], do: url

  defp build_url_with_params(url, params) do
    query_string = URI.encode_query(params)
    "#{url}?#{query_string}"
  end

  defp maybe_decode(msg) when is_binary(msg) do
    case Jason.decode(msg) do
      {:ok, decoded} -> decoded
      {:error, _} -> msg
    end
  end
end
