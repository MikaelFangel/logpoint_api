defmodule Logpoint do
  @moduledoc """
  This module provides the interface for interacting with a logpoint instance.
  """

  alias Logpoint.Client
  alias Logpoint.Client.Supervisor

  def start_supervisor, do: Supervisor.start_link(nil)
  def new(ip, username, secret_key), do: Supervisor.start_client(ip, username, secret_key)
  def submit_search(pid, query), do: Client.submit_search(pid, query)
  def search_status(pid, search_id), do: Client.search_status(pid, search_id)
  def search_result(pid, search_id), do: Client.search_result(pid, search_id)
  def searches(pid, status), do: Client.searches(pid, status)
  def user_preference(pid), do: Client.allowed_data(pid, :user_preference)
  def loginspects(pid), do: Client.allowed_data(pid, :loginspects)
  def logpoint_repos(pid), do: Client.allowed_data(pid, :logpoint_repos)
  def devices(pid), do: Client.allowed_data(pid, :devices)
  def livesearches(pid), do: Client.allowed_data(pid, :livesearches)

  def incident(pid, incident_obj_id, incident_id), do: Client.incident_info(pid, incident_obj_id, incident_id)

  def incidents(pid, start_time, end_time), do: Client.incident_info(pid, :incidents, start_time, end_time)

  def incident_states(pid, start_time, end_time), do: Client.incident_info(pid, :incident_states, start_time, end_time)

  def assign_incidents(pid, incident_ids, assignee_id), do: Client.assign_incidents(pid, incident_ids, assignee_id)

  def add_comments(pid, comments), do: Client.add_comments(pid, comments)

  def resolve_incidents(pid, indent_ids), do: Client.update_incidents(pid, :resolve, indent_ids)

  def close_incidents(pid, indent_ids), do: Client.update_incidents(pid, :close, indent_ids)

  def reopen_incidents(pid, indent_ids), do: Client.update_incidents(pid, :reopen, indent_ids)

  def users(pid), do: Client.users(pid)
  def stop(pid), do: Supervisor.stop_client(pid)
end
