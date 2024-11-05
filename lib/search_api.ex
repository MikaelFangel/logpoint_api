defmodule LogpointApi.SearchApi do
  @moduledoc """
  This module provides an implementation of the Logpoint search API.
  """

  alias LogpointApi.Client

  @allowed_types [:user_preference, :loginspects, :logpoint_repos, :devices, :livesearches]

  defmodule Query do
    @typedoc """
    Struct representing a Logpoint search query.
    """
    @type t :: %__MODULE__{
            query: String.t(),
            time_range: list(),
            limit: Number.t(),
            repos: list()
          }
    @derive {Jason.Encoder, only: [:query, :time_range, :limit, :repos]}
    defstruct [:query, :time_range, :limit, :repos]
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

  @doc false
  @spec make_request(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  defp make_request(ip, path, payload) do
    url = build_url(ip, path)
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    # On-prem uses self signed certificates and we thus need to disable the verification.
    options = [ssl: [{:verify, :verify_none}], recv_timeout: :infinity]

    case HTTPoison.post(url, payload, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received response with status code #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed with reason: #{reason}"}
    end
  end

  @doc false
  @spec build_url(String.t(), String.t()) :: String.t()
  defp build_url(ip, path), do: "https://" <> ip <> path

  @doc false
  @spec get_allowed_data(Client.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_allowed_data(client, type) when type in @allowed_types do
    payload = build_payload(client, %{"type" => Atom.to_string(type)})
    make_request(client.ip, "/getalloweddata", payload)
  end

  @doc false
  @spec get_search_logs(Client.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defp get_search_logs(client, request_data) do
    payload = build_payload(client, %{"requestData" => Jason.encode!(request_data)})
    make_request(client.ip, "/getsearchlogs", payload)
  end

  @doc false
  @spec build_payload(Client.t(), map()) :: String.t()
  defp build_payload(%Client{} = client, data) do
    Map.merge(
      %{
        "username" => client.username,
        "secret_key" => client.secret_key
      },
      data
    )
    |> URI.encode_query()
  end
end
