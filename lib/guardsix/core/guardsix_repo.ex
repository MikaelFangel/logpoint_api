defmodule Guardsix.Core.GuardsixRepo do
  @moduledoc """
  List searchable repos.

  Wraps the [Repos API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/repos_api).
  """

  alias Guardsix.Auth.JwtProvider
  alias Guardsix.Data.Client
  alias Guardsix.Error
  alias Guardsix.Net.JwtClient

  @doc """
  List all searchable repos.
  """
  @spec list(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def list(%Client{} = client) do
    case JwtProvider.logsource_read_token(client.credential) do
      {:ok, token, _claims} ->
        JwtClient.post_json(req(client), "/Repo/get_all_searchable_logpoint", token, %{})

      {:error, _reason} = error ->
        error
    end
  end

  defp req(%Client{} = client) do
    JwtClient.new(client.base_url, client.ssl_verify)
  end
end
