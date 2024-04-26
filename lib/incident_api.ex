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
