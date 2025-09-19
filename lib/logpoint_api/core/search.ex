defmodule LogpointApi.Core.Search do
  @moduledoc false

  alias LogpointApi.Data.SearchParams
  alias LogpointApi.Net.SearchIncidentClient

  @allowed_types [:user_preference, :loginspects, :logpoint_repos, :devices, :livesearches]

  @doc """
  Gets allowed data from the Logpoint instance.
  """
  def get_allowed_data(req, credential, type) when type in @allowed_types do
    SearchIncidentClient.post_form(req, "/getalloweddata", credential, %{type: type})
  end

  @doc """
  Performs search log operations (both search creation and result retrieval).
  """
  def get_search_logs(req, credential, %SearchParams{} = params) do
    request_data = SearchParams.to_form_data(params)
    request = create_encoded_request(request_data)
    SearchIncidentClient.post_form(req, "/getsearchlogs", credential, request)
  end

  def get_search_logs(req, credential, search_id) when is_binary(search_id) do
    request = create_encoded_request(%{search_id: search_id})
    SearchIncidentClient.post_form(req, "/getsearchlogs", credential, request)
  end

  defp create_encoded_request(params) do
    %{requestData: Jason.encode!(params)}
  end
end
