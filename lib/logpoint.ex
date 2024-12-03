defmodule Logpoint do
  @moduledoc """
  This module provides the interface for interacting with a logpoint instance.
  """

  alias Logpoint.Client.Supervisor
  alias Logpoint.Client

  def start_supervisor, do: Supervisor.start_link(nil)
  def new(ip, username, secret_key), do: Supervisor.start_client(ip, username, secret_key)
  def submit_search(pid, query), do: Client.submit_search(pid, query)
  def search_status(pid, search_id), do: Client.search_status(pid, search_id)
  def search_result(pid, search_id), do: Client.search_result(pid, search_id)
  def searches(pid, status), do: Client.searches(pid, status)
  def allowed_data(pid, type), do: Client.allowed_data(pid, type)
  def stop(pid), do: Supervisor.stop_client(pid)
end
