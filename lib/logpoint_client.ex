defmodule LogpointClient do
  use GenServer
  alias LogpointApi.Query

  def start_link(client) do
    GenServer.start_link(__MODULE__, %{client: client, searches: %{}})
  end

  def run_search(pid, %Query{} = query) do
    GenServer.call(pid, {:run_search, query})
  end

  def submit_search(pid, %Query{} = query) do
    GenServer.cast(pid, {:submit_search, query, self()})

    receive do
      {:search_id, search_id} ->
        {:ok, search_id}

      {:error, reason} ->
        {:error, reason}
    after
      5000 -> {:error, :timeout}
    end
  end

  def get_search_status(pid, search_id) do
    GenServer.call(pid, {:get_search_status, search_id})
  end

  def search_result(pid, search_id) do
    GenServer.call(pid, {:get_search_result, search_id})
  end

  def get_allowed_data(pid, type) do
    GenServer.call(pid, {:get_allowed_data, type})
  end

  @impl true
  def init(client) do
    {:ok, %{client: client, searches: %{}}}
  end

  @impl true
  def handle_call({:run_search, query}, _from, state) do
    result = LogpointApi.run_search(state.client, query)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_allowed_data, type}, _from, state) do
    result = LogpointApi.get_allowed_data(state.client, type)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_search_status, search_id}, _from, %{searches: searches} = state) do
    status = Map.get(searches, search_id, %{status: :unknown})[:status]
    {:reply, status, state}
  end

  @impl true
  def handle_call({:get_search_result, search_id}, _from, %{searches: searches} = state) do
    case Map.get(searches, search_id) do
      nil -> {:reply, {:error, :not_found}, state}
      %{result: result} -> {:reply, {:ok, result}, state}
      _ -> {:reply, {:error, :not_ready}, state}
    end
  end

  @impl true
  def handle_cast({:submit_search, query, caller}, %{client: client, searches: searches} = state) do
    case LogpointApi.get_search_id(client.client, query) do
      {:ok, %{"search_id" => search_id}} ->
        updated_searches = Map.put(searches, search_id, %{query: query, status: :pending})
        new_state = %{state | searches: updated_searches}

        send(caller, {:search_id, search_id})

        server_pid = self()
        Task.start(fn -> poll_search_result(server_pid, client.client, search_id) end)

        {:noreply, new_state}

      {:error, reason} ->
        send(caller, {:error, reason})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:search_complete, search_id, {:ok, result}}, %{searches: searches} = state) do
    updated_searches =
      Map.update(searches, search_id, %{status: :complete, result: result}, fn search ->
        Map.put(search, :status, :complete) |> Map.put(:result, result)
      end)

    {:noreply, %{state | searches: updated_searches}}
  end

  @impl true
  def handle_info({:search_complete, search_id, {:error, reason}}, %{searches: searches} = state) do
    updated_searches =
      Map.update(searches, search_id, %{status: :failed, error: reason}, fn search ->
        Map.put(search, :status, :failed) |> Map.put(:error, reason)
      end)

    {:noreply, %{state | searches: updated_searches}}
  end

  defp poll_search_result(server, client, search_id) do
    case LogpointApi.get_search_result(client, search_id) do
      {:ok, %{"final" => true} = result} ->
        send(server, {:search_complete, search_id, {:ok, result}})

      {:ok, %{"final" => false}} ->
        :timer.sleep(1000)
        poll_search_result(server, client, search_id)

      {:error, reason} ->
        send(server, {:search_complete, search_id, {:error, reason}})
    end
  end
end
