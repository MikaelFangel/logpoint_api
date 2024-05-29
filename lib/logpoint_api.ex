defmodule LogpointApi do
  @moduledoc """
  This module provides an implementation of the Logpoint API.
  """

  alias LogpointApi.SearchApi.Query
  alias LogpointApi.SearchApi

  defmodule Credential do
    @typedoc """
    Struct representing credentials used for authorization.
    """
    @type t :: %__MODULE__{username: String.t(), secret_key: String.t()}
    defstruct [:username, :secret_key]
  end

  @doc """
  Run a search query.
  """
  @spec run_search(String.t(), Credential.t(), Query.t()) :: map()
  def run_search(ip, credential, %Query{} = query) do
    {:ok, %{"success" => true} = search_info} = SearchApi.get_search_id(ip, credential, query)
    search_id = Map.get(search_info, "search_id")

    SearchApi.get_search_result(ip, credential, search_id)
    |> handle_search_result(ip, credential, search_id, query)
  end

  defp handle_search_result({:ok, %{"final" => true} = result}, _, _, _, _), do: result

  defp handle_search_result(
         {:ok, %{"final" => false}},
         ip,
         credential,
         search_id,
         query
       ) do
    result = SearchApi.get_search_result(ip, credential, search_id)

    # Wait before retrying.
    :timer.sleep(1000)

    handle_search_result(result, ip, credential, search_id, query)
  end

  defp handle_search_result(
         {:ok, %{"success" => false}},
         ip,
         credential,
         _,
         query
       ) do
    # Wait before recreating the search.
    :timer.sleep(1000)

    run_search(ip, credential, query)
  end
end
