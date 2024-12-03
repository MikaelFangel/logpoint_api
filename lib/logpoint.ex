defmodule Logpoint do
  @moduledoc """
  This module provides the interface for interacting with a logpoint instance.
  """

  alias Logpoint.Client.Supervisor
  alias Logpoint.Client

  def start_supervisor do
    Supervisor.start_link(nil)
  end

  def new(ip, username, secret_key) do
    Supervisor.start_client(ip, username, secret_key)
  end

  def submit_search(pid, query) do
    Client.submit_search(pid, query)
  end

  def search_status(pid, search_id) do
    Client.search_status(pid, search_id)
  end

  def search_result(pid, search_id) do
    Client.search_result(pid, search_id)
  end

  def stop(pid) do
    Supervisor.stop_client(pid)
  end
end
