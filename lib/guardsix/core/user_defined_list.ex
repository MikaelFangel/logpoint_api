defmodule Guardsix.Core.UserDefinedList do
  @moduledoc """
  Manage user-defined lists in Guardsix.

  Wraps the [User Defined Lists API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/user-defined-lists-api).

  For session-based operations (`extract`, `update_static`, `delete`), see
  `Guardsix.Core.UserDefinedListBySession`.
  """

  alias Guardsix.Auth.JwtProvider
  alias Guardsix.Data.Client
  alias Guardsix.Error
  alias Guardsix.Net.JwtClient

  @doc """
  List user defined lists.

  Supported keys in `params`:

    * `:limit` - maximum number of lists to return
    * `:page` - page number for pagination
    * `:return_all_data` - when `true`, returns all list data

  ## Examples

      UserDefinedList.list(client)
      UserDefinedList.list(client, %{limit: 25, page: 2})

  """
  @spec list(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}) do
    with_read_token(client, fn token ->
      JwtClient.get(req(client), "/UserDefinedList/lists_api", token, params)
    end)
  end

  @doc """
  Import a static list from CSV or TXT content.
  """
  @spec import_static(Client.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def import_static(%Client{} = client, name, content) when is_binary(name) and is_binary(content) do
    body = %{
      package_import_name: name,
      package_import: {content, filename: "#{name}.csv", content_type: "text/csv"}
    }

    with_write_token(client, fn token ->
      JwtClient.post_multipart(req(client), "/UserDefinedList/import_api", token, body)
    end)
  end

  @name_pattern ~r/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,98}[a-zA-Z0-9]$/

  @doc """
  Validate a list name against LogPoint's naming rules.

  Names must be 2-100 characters, alphanumeric with hyphens and underscores,
  and must not begin or end with whitespace, hyphens, or underscores.
  Names are automatically uppercased by LogPoint.

  ## Examples

      :ok = UserDefinedList.validate_name("MY_LIST")
      {:error, %Error.Validation{errors: %{"name" => _}}} = UserDefinedList.validate_name("_invalid")

  """
  @spec validate_name(String.t()) :: :ok | {:error, Error.Validation.t()}
  def validate_name(name) when is_binary(name) do
    cond do
      String.length(name) < 2 ->
        name_error("must be at least 2 characters")

      String.length(name) > 100 ->
        name_error("must be at most 100 characters")

      not Regex.match?(@name_pattern, name) ->
        name_error(
          "must be alphanumeric with hyphens and underscores, " <>
            "and must not begin or end with whitespace, hyphens, or underscores"
        )

      true ->
        :ok
    end
  end

  defp name_error(complaint), do: {:error, Error.Validation.new(%{"name" => complaint})}

  defp with_read_token(%Client{} = client, fun) do
    case JwtProvider.search_read_token(client.credential) do
      {:ok, token, _claims} -> fun.(token)
      {:error, _reason} = error -> error
    end
  end

  defp with_write_token(%Client{} = client, fun) do
    case JwtProvider.search_write_token(client.credential) do
      {:ok, token, _claims} -> fun.(token)
      {:error, _reason} = error -> error
    end
  end

  defp req(%Client{} = client) do
    JwtClient.new(client.base_url, client.ssl_verify)
  end
end
