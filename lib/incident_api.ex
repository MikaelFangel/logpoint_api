defmodule LogpointApi.IncidentApi do
  alias LogpointApi.Credential, as: Credential

  defmodule TimePeriod do
    @derive {Jason.Encoder, only: [:version, :ts_from, :ts_to]}
    defstruct [:ts_from, :ts_to, version: "0.1"]
  end

  defmodule Incident do
    @derive {Jason.Encoder, only: [:incident_obj_id, :incident_id]}
    defstruct [:incident_obj_id, :incident_id]
  end

  def get_incidents(ip, %Credential{} = credential, %TimePeriod{} = request_data) do
    get_incident_information(ip, "/incidents", credential, request_data)
  end

  def get_data_from_incident(ip, %Credential{} = credential, %Incident{} = incident) do
    get_incident_information(ip, "/get_data_from_incident", credential, incident)
  end

  defp get_incident_information(ip, path, %Credential{} = credential, request_data) do
    params = %{
      "username" => credential.username,
      "secret_key" => credential.secret_key,
      "requestData" => request_data
    }

    make_request(ip, path, params)
  end

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
