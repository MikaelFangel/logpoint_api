defmodule LogpointApi.SearchApi do
  @moduledoc """
  This module provides an implementation of the Logpoint search API.
  """

  alias LogpointApi.Credential

  @allowed_types ["user_preference", "loginspects", "logpoint_repos", "devices", "livesearches"]

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

  defmodule SearchID do
    @typedoc """
    Struct representing a search id.
    """
    @type t :: %__MODULE__{search_id: String.t()}
    @derive {Jason.Encoder, only: [:search_id]}
    defstruct [:search_id]
  end

  @doc """
  Get the current users time zone information.
  """
  @spec get_user_timezone(String.t(), Credential.t()) :: {:ok, map()} | {:error, String.t()}
  def get_user_timezone(ip, credential),
    do: get_allowed_data(ip, credential, "user_preference")

  @doc """
  Get all logpoints of a Logpoint instance.
  """
  @spec get_logpoints(String.t(), Credential.t()) :: {:ok, map()} | {:error, String.t()}
  def get_logpoints(ip, credential),
    do: get_allowed_data(ip, credential, "loginspects")

  @doc """
  Get the repos of an instance.
  """
  @spec get_repos(String.t(), Credential.t()) :: {:ok, map()} | {:error, String.t()}
  def get_repos(ip, credential),
    do: get_allowed_data(ip, credential, "logpoint_repos")

  @doc """
  Get the devices of the instance.
  """
  @spec get_devices(String.t(), Credential.t()) :: {:ok, map()} | {:error, String.t()}
  def get_devices(ip, credential),
    do: get_allowed_data(ip, credential, "devices")

  @doc """
  Get all live search on a machine.
  """
  @spec get_livesearches(String.t(), Credential.t()) :: {:ok, map()} | {:error, String.t()}
  def get_livesearches(ip, credential),
    do: get_allowed_data(ip, credential, "livesearches")

  @doc """
  Create a search and get its search id.
  """
  @spec get_search_id(String.t(), Credential.t(), Query.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_search_id(ip, credential, %Query{} = query),
    do: get_search_logs(ip, credential, query)

  @doc """
  Retrieve the search result of a specific search id.
  """
  @spec get_search_result(String.t(), Credential.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_search_result(ip, credential, search_id),
    do: get_search_logs(ip, credential, %SearchID{search_id: search_id})

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
  @spec get_allowed_data(String.t(), Credential.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  defp get_allowed_data(ip, credential, type) when type in @allowed_types do
    payload = build_payload(credential, %{"type" => type})
    make_request(ip, "/getalloweddata", payload)
  end

  @doc false
  @spec get_search_logs(String.t(), Credential.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defp get_search_logs(ip, credential, request_data) do
    payload = build_payload(credential, %{"requestData" => Jason.encode!(request_data)})
    make_request(ip, "/getsearchlogs", payload)
  end

  @doc false
  @spec build_payload(Credential.t(), map()) :: String.t()
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
