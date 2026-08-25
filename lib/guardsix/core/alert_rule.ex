defmodule Guardsix.Core.AlertRule do
  @moduledoc """
  Manage alert rules and their notifications in Guardsix.

  Wraps the [Alert Rules API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/alert_rules_api).
  Use the `Rule`, `EmailNotification`, and `HttpNotification` builders to compose
  structs for creation endpoints.
  """

  alias Guardsix.Auth.JwtProvider
  alias Guardsix.Data.Client
  alias Guardsix.Data.EmailNotification
  alias Guardsix.Data.HttpNotification
  alias Guardsix.Data.Rule
  alias Guardsix.Error
  alias Guardsix.Net.JwtClient

  @doc """
  List alert rules.

  Supported keys in `params`:

    * `:limit` - maximum number of rules to return
    * `:page` - page number for pagination
    * `:return_all_data` - when `true`, returns all rule data

  ## Examples

      AlertRule.list(client)
      AlertRule.list(client, %{limit: 10, page: 1})

  """
  @spec list(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}) do
    with_read_token(client, fn token ->
      JwtClient.get(req(client), "/AlertRules/lists_api", token, params)
    end)
  end

  @doc """
  Get an alert rule by ID.
  """
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(%Client{} = client, id) when is_binary(id) do
    with_read_token(client, fn token ->
      JwtClient.get(req(client), "/AlertRules/read_api", token, %{id: id})
    end)
  end

  @doc """
  Create an alert rule.
  """
  @spec create(Client.t(), Rule.t() | map()) :: {:ok, map()} | {:error, Error.t()}
  def create(%Client{} = client, %Rule{} = rule) do
    with :ok <- Rule.validate(rule) do
      create(client, Rule.to_payload(rule))
    end
  end

  def create(%Client{} = client, rule) when is_map(rule) do
    with_write_token(client, fn token ->
      JwtClient.post_json(req(client), "/AlertRules/create_api", token, rule)
    end)
  end

  @doc """
  Update an alert rule.
  """
  @spec update(Client.t(), String.t(), Rule.t() | map()) :: {:ok, map()} | {:error, Error.t()}
  def update(%Client{} = client, id, %Rule{} = rule) when is_binary(id) do
    with :ok <- Rule.validate(rule) do
      update(client, id, Rule.to_payload(rule))
    end
  end

  def update(%Client{} = client, id, rule) when is_binary(id) and is_map(rule) do
    with_write_token(client, fn token ->
      JwtClient.post_json(req(client), "/AlertRules/update_api", token, Map.put(rule, :id, id))
    end)
  end

  for {function_name, path} <- [
        delete: "delete_api",
        activate: "activate_api",
        deactivate: "deactivate_api"
      ] do
    @doc """
    #{function_name |> to_string() |> String.capitalize()} alert rules by IDs.
    """
    @spec unquote(function_name)(Client.t(), [String.t()]) :: {:ok, map()} | {:error, Error.t()}
    def unquote(function_name)(%Client{} = client, ids) when is_list(ids) do
      with_write_token(client, fn token ->
        JwtClient.post_json(req(client), "/AlertRules/#{unquote(path)}", token, %{ids: ids})
      end)
    end
  end

  @doc """
  Get alert notification by alert ID and type.
  """
  @spec get_notification(Client.t(), String.t(), :email | :http) ::
          {:ok, map()} | {:error, Error.t()}
  def get_notification(%Client{} = client, alert_id, type) when type in [:email, :http] do
    path =
      case type do
        :email -> "/pluggables/Notification/EmailNotification/read_api"
        :http -> "/pluggables/Notification/HTTPNotification/read_api"
      end

    with_read_token(client, fn token ->
      JwtClient.get(req(client), path, token, %{id: alert_id})
    end)
  end

  @doc """
  Create an email notification for alert rules.
  """
  @spec create_email_notification(Client.t(), EmailNotification.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_email_notification(%Client{} = client, %EmailNotification{} = notif) do
    with :ok <- EmailNotification.validate(notif) do
      body = Map.put(EmailNotification.to_payload(notif), :type, "email")

      with_write_token(client, fn token ->
        JwtClient.post_form(
          req(client),
          "/pluggables/Notification/EmailNotification/create_api",
          token,
          body
        )
      end)
    end
  end

  @spec create_email_notification(Client.t(), [String.t()], map()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_email_notification(%Client{} = client, ids, params) when is_list(ids) and is_map(params) do
    body = Map.merge(params, %{ids: ids, type: "email"})

    with_write_token(client, fn token ->
      JwtClient.post_form(
        req(client),
        "/pluggables/Notification/EmailNotification/create_api",
        token,
        body
      )
    end)
  end

  @doc """
  Create an HTTP notification for alert rules.
  """
  @spec create_http_notification(Client.t(), HttpNotification.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_http_notification(%Client{} = client, %HttpNotification{} = notif) do
    with :ok <- HttpNotification.validate(notif) do
      body = Map.put(HttpNotification.to_payload(notif), :type, "http")

      with_write_token(client, fn token ->
        JwtClient.post_json(
          req(client),
          "/pluggables/Notification/HTTPNotification/create_api",
          token,
          body
        )
      end)
    end
  end

  @spec create_http_notification(Client.t(), [String.t()], map()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_http_notification(%Client{} = client, ids, params) when is_list(ids) and is_map(params) do
    body = Map.merge(params, %{ids: ids, type: "http"})

    with_write_token(client, fn token ->
      JwtClient.post_json(
        req(client),
        "/pluggables/Notification/HTTPNotification/create_api",
        token,
        body
      )
    end)
  end

  defp with_read_token(%Client{} = client, fun) do
    case JwtProvider.alert_rule_read_token(client.credential) do
      {:ok, token, _claims} -> fun.(token)
      {:error, _reason} = error -> error
    end
  end

  defp with_write_token(%Client{} = client, fun) do
    case JwtProvider.alert_rule_write_token(client.credential) do
      {:ok, token, _claims} -> fun.(token)
      {:error, _reason} = error -> error
    end
  end

  defp req(%Client{} = client) do
    JwtClient.new(client.base_url, client.ssl_verify)
  end
end
