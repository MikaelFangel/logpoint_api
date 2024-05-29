defmodule LogpointApi do
  @moduledoc false

  alias LogpointApi.SearchApi.Query
  alias LogpointApi.SearchApi

  defmodule Credential do
    @typedoc """
    Struct representing credentials used for authorization.
    """
    @type t :: %__MODULE__{username: String.t(), secret_key: String.t()}
    defstruct [:username, :secret_key]
  end

  @spec run_search(String.t(), Credential.t(), Query.t()) :: {:ok, map()} | {:error, String.t()}
  def run_search(ip, credential, %Query{} = query) do
    {:ok, search_info} = SearchApi.get_search_id(ip, credential, query)
    search_id = Map.get(search_info, "search_id")

    SearchApi.get_search_result(ip, credential, search_id)
    |> handle_search_result(ip, credential, search_id, query)
  end

  defp handle_search_result({:ok, %{"final" => true} = result}, _, _, _, _), do: result

  defp handle_search_result(
         {:ok, %{"final" => false, "succes" => true}},
         ip,
         credential,
         search_id,
         query
       ) do
    SearchApi.get_search_result(ip, credential, search_id)
    |> handle_search_result(ip, credential, search_id, query)
  end

  defp handle_search_result(
         {:ok, %{"final" => false, "success" => false}},
         ip,
         credential,
         _,
         query
       ) do
    run_search(ip, credential, query)
  end
end
