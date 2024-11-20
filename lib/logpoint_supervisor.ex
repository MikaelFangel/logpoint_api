defmodule LogpointClientSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_client(client) do
    DynamicSupervisor.start_child(__MODULE__, {LogpointClient, client})
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
