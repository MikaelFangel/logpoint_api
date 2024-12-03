defmodule Logpoint.Client do
  @moduledoc false

  use GenServer, restart: :transient
  alias Logpoint.Api.Query

  @typedoc """
  Struct representing credentials used for authorization.
  """
  @type t :: %__MODULE__{ip: String.t(), username: String.t(), secret_key: String.t()}
  defstruct [:ip, :username, :secret_key]

  def new(ip, username, secret_key) do
    GenServer.start_link(__MODULE__, %{
      client: %Logpoint.Client{ip: ip, username: username, secret_key: secret_key},
      searches: %{}
    })
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

  def search_status(pid, search_id), do: GenServer.call(pid, {:search_status, search_id})
  def search_result(pid, search_id), do: GenServer.call(pid, {:search_result, search_id})

  def searches(pid, status) when status in [:pending, :complete],
    do: GenServer.call(pid, {:searches, status})

  def allowed_data(pid, type), do: GenServer.call(pid, {:allowed_data, type})

  def incident_info(pid, incident_obj_id, incident_id),
    do: GenServer.call(pid, {:incident_info, incident_obj_id, incident_id})

  def incident_info(pid, action, start_time, end_time),
    do: GenServer.call(pid, {:incident_info, action, start_time, end_time})

  def assign_incidents(pid, incident_ids, assingee_id),
    do: GenServer.call(pid, {:assign_incidents, incident_ids, assingee_id})

  @doc """
  %{"id" => ["1", "2", "3"]}
  """
  def add_comments(pid, comments),
    do: GenServer.call(pid, {:add_comments, comments})

  def update_incidents(pid, action, indent_ids),
    do: GenServer.call(pid, {:update_incidents, action, indent_ids})

  def users(pid), do: GenServer.call(pid, {:users})

  @impl true
  def init(client), do: {:ok, %{client: client, searches: %{}}}

  @impl true
  def handle_call({:allowed_data, type}, _from, state) do
    result = Logpoint.Api.get_allowed_data(state.client.client, type)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:search_status, search_id}, _from, %{searches: searches} = state) do
    status = Map.get(searches, search_id, %{status: :unknown})[:status]
    {:reply, status, state}
  end

  @impl true
  def handle_call({:search_result, search_id}, _from, %{searches: searches} = state) do
    case Map.get(searches, search_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{result: result} ->
        searches = Map.delete(searches, search_id)
        state = %{state | searches: searches}
        {:reply, {:ok, result}, state}

      _ ->
        {:reply, {:error, :not_ready}, state}
    end
  end

  @impl true
  def handle_call({:searches, status}, _from, %{searches: searches} = state) do
    search_ids =
      searches
      |> Enum.filter(fn {_search_id, search_data} -> search_data[:status] == status end)
      |> Enum.map(fn {search_id, _search_data} -> search_id end)

    {:reply, search_ids, state}
  end

  @impl true
  def handle_call({:incident_info, incident_obj_id, incident_id}, _from, state) do
    info =
      Logpoint.Api.get_incident_info(
        state.client.client,
        Logpoint.Api.Incident.new(incident_obj_id, incident_id)
      )

    {:reply, info, state}
  end

  @impl true
  def handle_call({:incident_info, action, start_time, end_time}, _from, state) do
    info =
      Logpoint.Api.get_incident_info(
        state.client.client,
        action,
        Logpoint.Api.TimeRange.new(start_time, end_time)
      )

    {:reply, info, state}
  end

  @impl true
  def handle_call({:users}, _from, state) do
    users = Logpoint.Api.get_users(state.client.client)
    {:reply, users, state}
  end

  @impl true
  def handle_call({:add_comments, comments}, _from, state) do
    comments =
      comments
      |> Enum.map(fn {k, v} -> Logpoint.Api.IncidentComment.new(k, v) end)

    comment_data = Logpoint.Api.IncidentCommentData.new("0.1", comments)
    result = Logpoint.Api.add_comments(state.client.client, comment_data)

    {:reply, result, state}
  end

  def handle_call({:assign_incidents, incident_ids, assingee_id}, _from, state) do
    result =
      Logpoint.Api.assign_incidents(
        state.client.client,
        Logpoint.Api.IncidentIDs.new("0.1", incident_ids),
        assingee_id
      )

    {:reply, result, state}
  end

  def handle_call({:update_incidents, action, incident_ids}, _from, state) do
    result =
      Logpoint.Api.update_incidents(
        state.client.client,
        action,
        Logpoint.Api.IncidentIDs.new("0.1", incident_ids)
      )

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:submit_search, query, caller}, %{client: client, searches: searches} = state) do
    case Logpoint.Api.get_search_id(client.client, query) do
      {:ok, %{"search_id" => search_id}} ->
        updated_searches = Map.put(searches, search_id, %{query: query, status: :pending})
        new_state = %{state | searches: updated_searches}

        send(caller, {:search_id, search_id})

        server_pid = self()

        Task.start(fn ->
          poll_search_result(server_pid, client.client, search_id, query, search_id)
        end)

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

  defp poll_search_result(server, client, search_id, query, original_search_id) do
    case Logpoint.Api.get_search_result(client, search_id) do
      {:ok, %{"final" => true} = result} ->
        send(server, {:search_complete, original_search_id, {:ok, result}})

      {:ok, %{"final" => false}} ->
        :timer.sleep(1000)
        poll_search_result(server, client, search_id, query, original_search_id)

      {:ok, %{"success" => false}} ->
        case Logpoint.Api.get_search_id(client, query) do
          {:ok, %{"search_id" => new_search_id}} ->
            poll_search_result(server, client, new_search_id, query, original_search_id)

          {:error, reason} ->
            send(server, {:search_complete, original_search_id, {:error, reason}})
        end

      {:error, reason} ->
        send(server, {:search_complete, original_search_id, {:error, reason}})
    end
  end
end
