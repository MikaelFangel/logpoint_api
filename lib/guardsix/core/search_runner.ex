defmodule Guardsix.Core.SearchRunner do
  @moduledoc """
  Blocking polling for Guardsix searches.

  The Guardsix search API is asynchronous — submit a query, then poll for
  results. `run/3` handles the polling loop, including resubmitting expired
  searches automatically.
  """

  alias Guardsix.Core.Search
  alias Guardsix.Data.Client
  alias Guardsix.Data.SearchParams
  alias Guardsix.Error

  @default_polling_interval 1_000
  @default_max_attempts 30

  @doc """
  Run a search and block until final results arrive.

  Polls `Search.get_result/2` until the response contains `"final" => true`.
  When the API returns a `"Forgotten search"` error (expired search), the
  original query is resubmitted automatically.

  Returns a `Guardsix.Error.Timeout` if the search has not finished after
  `:max_attempts` polls. The search is not cancelled — the error carries the
  `search_id` so it can still be polled directly.

  ## Options

    * `:polling_interval` — milliseconds between polls (default: `#{@default_polling_interval}`)
    * `:max_attempts`     — maximum poll iterations (default: `#{@default_max_attempts}`)

  ## Examples

      {:ok, result} = SearchRunner.run(client, query)
      {:ok, result} = SearchRunner.run(client, query, polling_interval: 2_000, max_attempts: 30)

  """
  @spec run(Client.t(), SearchParams.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def run(%Client{} = client, %SearchParams{} = query, opts \\ []) do
    polling_interval = Keyword.get(opts, :polling_interval, @default_polling_interval)
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)

    case Search.get_id(client, query) do
      {:ok, %{"search_id" => search_id}} ->
        poll(client, query, search_id, polling_interval, max_attempts)

      {:error, error} ->
        {:error, error}
    end
  end

  defp poll(client, query, search_id, polling_interval, max_attempts, attempt \\ 1)

  defp poll(_client, _query, search_id, _polling_interval, max_attempts, attempt) when attempt > max_attempts,
    do: {:error, %Error.Timeout{attempts: max_attempts, search_id: search_id}}

  defp poll(client, query, search_id, polling_interval, max_attempts, attempt) do
    case Search.get_result(client, search_id) do
      {:ok, %{"final" => true} = result} ->
        {:ok, result}

      {:ok, %{"final" => false}} ->
        Process.sleep(polling_interval)
        poll(client, query, search_id, polling_interval, max_attempts, attempt + 1)

      {:error, %Error.API{message: "Forgotten search"}} ->
        case Search.get_id(client, query) do
          {:ok, %{"search_id" => new_id}} ->
            poll(client, query, new_id, polling_interval, max_attempts, attempt + 1)

          error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end
end
