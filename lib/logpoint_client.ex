defmodule LogpointClient do
  use GenServer
  alias LogpointApi.Query

  def start_link(client) do
    GenServer.start_link(__MODULE__, client)
  end

  def run_search(pid, %Query{} = query) do
    GenServer.call(pid, {:run_search, query})
  end

  def get_search_id(pid, %Query{} = query) do
    GenServer.call(pid, {:get_search_id, query})
  end

  def get_search_result(pid, search_id) when is_binary(search_id) do
    GenServer.call(pid, {:get_search_result, search_id})
  end

  def get_allowed_data(pid, type) when is_atom(type) do
    GenServer.call(pid, {:get_allowed_data, type})
  end

  @impl true
  def init(client) do
    {:ok, client}
  end

  @impl true
  def handle_call({:run_search, query}, _from, client) do
    result = LogpointApi.run_search(client, query)
    {:reply, result, client}
  end

  @impl true
  def handle_call({:get_allowed_data, type}, _from, client) do
    result = LogpointApi.get_allowed_data(client, type)
    {:reply, result, client}
  end

  @impl true
  def handle_call({:get_search_id, query}, _from, client) do
    result = LogpointApi.get_search_id(client, query)
    {:reply, result, client}
  end

  @impl true
  def handle_call({:get_search_result, search_id}, _from, client) do
    result = LogpointApi.get_search_result(client, search_id)
    {:reply, result, client}
  end
end
