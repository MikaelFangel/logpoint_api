defmodule LogpointApi do
  @moduledoc """
  This module provides an implementation of the Logpoint API.
  """

  alias LogpointApi.SearchApi.Query
  alias LogpointApi.SearchApi

  defmodule Client do
    @moduledoc false
    @typedoc """
    Struct representing credentials used for authorization.
    """
    @type t :: %__MODULE__{ip: String.t(), username: String.t(), secret_key: String.t()}
    defstruct [:ip, :username, :secret_key]

    @spec new(String.t(), String.t(), String.t()) :: t()
    def new(ip, username, secret_key) do
      %Client{ip: ip, username: username, secret_key: secret_key}
    end
  end

  @doc """
  Run a search query.
  """
  @spec run_search(Client.t(), Query.t()) :: map()
  def run_search(client, %Query{} = query) do
    {:ok, %{"success" => true} = search_info} = SearchApi.get_search_id(client, query)
    search_id = Map.get(search_info, "search_id")

    SearchApi.get_search_result(client, search_id)
    |> handle_search_result(client, search_id, query)
  end

  defp handle_search_result({:ok, %{"final" => true} = result}, _, _, _), do: result

  defp handle_search_result(
         {:ok, %{"final" => false}},
         client,
         search_id,
         query
       ) do
    result = SearchApi.get_search_result(client, search_id)

    # Wait before retrying.
    :timer.sleep(1000)

    handle_search_result(result, client, search_id, query)
  end

  defp handle_search_result(
         {:ok, %{"success" => false}},
         client,
         _,
         query
       ) do
    # Wait before recreating the search.
    :timer.sleep(1000)

    run_search(client, query)
  end
end
