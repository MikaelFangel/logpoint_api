defmodule Logpoint.Client.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_client(ip, username, secret_key) do
    spec = %{
      id: Logpoint.Client,
      start: {Logpoint.Client, :new, [ip, username, secret_key]}
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_client(pid), do: DynamicSupervisor.terminate_child(__MODULE__, pid)
end
