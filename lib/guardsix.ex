defmodule Guardsix do
  @moduledoc """
  Elixir library for interacting with the Guardsix API.

  Build a client, then pass it to any domain module.

  ## Setup

      client = Guardsix.client("https://guardsix.company.com", "admin", "secret")

  ## Search

      query = Guardsix.search_params("user=*", "Last 24 hours", 100, ["127.0.0.1"])

      # Block until final results (polls automatically)
      {:ok, result} = Guardsix.run_search(client, query)

      # Low-level primitives are still available
      alias Guardsix.Core.Search

      {:ok, %{"search_id" => id}} = Search.get_id(client, query)
      {:ok, result}               = Search.get_result(client, id)
      {:ok, prefs}                = Search.user_preference(client)
      {:ok, repos}                = Search.repos(client)

  ## Incidents

      alias Guardsix.Core.Incident

      {:ok, incidents} = Incident.list(client, start_time, end_time)
      {:ok, states}    = Incident.list_states(client, start_time, end_time)
      {:ok, _}         = Incident.resolve(client, ["id1"])
      {:ok, _}         = Incident.close(client, ["id2"])
      {:ok, _}         = Incident.reopen(client, ["id3"])
      {:ok, _}         = Incident.assign(client, ["id1"], "user_id")
      {:ok, _}         = Incident.add_comments(client, [Guardsix.comment("id1", "note")])
      {:ok, users}     = Incident.get_users(client)

  ## Alert Rules

      alias Guardsix.Data.Rule
      alias Guardsix.Core.AlertRule

      {:ok, rules} = AlertRule.list(client)
      {:ok, rule}  = AlertRule.get(client, "rule-id")
      {:ok, _}     = AlertRule.activate(client, ["id1", "id2"])
      {:ok, _}     = AlertRule.deactivate(client, ["id1"])
      {:ok, _}     = AlertRule.delete(client, ["id1"])

      # Builder-style alert rule creation
      rule =
        Guardsix.rule("Brute Force Detection")
        |> Rule.description("Detects brute force login attempts")
        |> Rule.query("error_code=4625")
        |> Rule.time_range(1, :day)
        |> Rule.repos(["10.0.0.1"])
        |> Rule.limit(100)
        |> Rule.threshold(:greaterthan, 5)
        |> Rule.risk_level("high")
        |> Rule.aggregation_type("max")
        |> Rule.assignee("admin")

      {:ok, _} = AlertRule.create(client, rule)

      # Email notification
      alias Guardsix.Data.EmailNotification

      notif =
        Guardsix.email_notification(["rule-1"], "admin@example.com")
        |> EmailNotification.subject("Alert: {{ rule_name }}")
        |> EmailNotification.template("<p>Details</p>")

      {:ok, _} = AlertRule.create_email_notification(client, notif)

      # HTTP notification
      alias Guardsix.Data.HttpNotification

      webhook =
        Guardsix.http_notification(["rule-1"], "https://hooks.slack.com/abc", :post)
        |> HttpNotification.body(~s({"text": "{{ rule_name }}"}))
        |> HttpNotification.bearer_auth("my-token")

      {:ok, _} = AlertRule.create_http_notification(client, webhook)

  ## Guardsix Repos & User-Defined Lists

      alias Guardsix.Core.GuardsixRepo
      alias Guardsix.Core.UserDefinedList
      alias Guardsix.Core.UserDefinedListBySession

      {:ok, repos} = GuardsixRepo.list(client)
      {:ok, lists} = UserDefinedList.list(client)

      # Session-based operations (unstable)
      {:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")
      {:ok, data} = UserDefinedListBySession.extract(session, "list-id")
      {:ok, _} = UserDefinedListBySession.update_static_by_name(session, "MY_LIST", ["val1"])
      {:ok, _} = UserDefinedListBySession.delete_by_name(session, "MY_LIST")

  ## SSL

      client = Guardsix.client("https://192.168.1.100", "admin", "secret", ssl_verify: false)
  """

  alias Guardsix.Core.SearchRunner
  alias Guardsix.Data.Client
  alias Guardsix.Data.Comment
  alias Guardsix.Data.Credential
  alias Guardsix.Data.EmailNotification
  alias Guardsix.Data.HttpNotification
  alias Guardsix.Data.Rule
  alias Guardsix.Data.SearchParams
  alias Guardsix.Error
  alias Guardsix.Net.BaseClient

  @js_version_pattern ~r/JS_VERSION\s*=\s*"([^"]+)"/
  @is_debug_pattern ~r/IS_DEBUG\s*=\s*eval\("(\w+)"/
  @default_auth_pattern ~r/DEFAULT_AUTH\s*=\s*"([^"]+)"/
  @failover_pattern ~r/FAIL_OVER_ENABLED\s*=\s*"(\w+)"/
  @semver_pattern ~r/^(\d+\.\d+\.\d+)/

  @doc """
  Fetch the version of a running Guardsix instance from its landing page.

  ## Options

    * `:format` - `:short` (default) returns the semantic version (e.g. `"7.7.1"`),
                  `:long` returns the full build version (e.g. `"7.7.1.0_1766842968"`)
    * `:ssl_verify` - verify SSL certificates (default: `true`)

  ## Examples

      {:ok, "7.7.1"} = Guardsix.version("https://guardsix.example.com")
      {:ok, "7.7.1.0_1766842968"} = Guardsix.version("https://guardsix.example.com", format: :long)

  """
  @spec version(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def version(base_url, opts \\ []) do
    format = Keyword.get(opts, :format, :short)

    case scrape_landing_page(base_url, @js_version_pattern, opts) do
      {:ok, raw_version} -> {:ok, format_version(raw_version, format)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Check whether a Guardsix instance is running in debug mode.

  ## Options

    * `:ssl_verify` - verify SSL certificates (default: `true`)

  ## Examples

      {:ok, false} = Guardsix.debug?("https://guardsix.example.com")

  """
  @spec debug?(String.t(), keyword()) :: {:ok, boolean()} | {:error, Error.t()}
  def debug?(base_url, opts \\ []) do
    case scrape_landing_page(base_url, @is_debug_pattern, opts) do
      {:ok, debug_flag} -> {:ok, String.downcase(debug_flag) == "true"}
      {:error, _} = error -> error
    end
  end

  @doc """
  Get the default authentication method of a Guardsix instance.

  ## Options

    * `:ssl_verify` - verify SSL certificates (default: `true`)

  ## Examples

      {:ok, "LogpointAuthentication"} = Guardsix.default_auth("https://guardsix.example.com")

  """
  @spec default_auth(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def default_auth(base_url, opts \\ []) do
    case scrape_landing_page(base_url, @default_auth_pattern, opts) do
      {:ok, auth} -> {:ok, auth}
      {:error, _} = error -> error
    end
  end

  @doc """
  Check whether a Guardsix instance has failover enabled.

  ## Options

    * `:ssl_verify` - verify SSL certificates (default: `true`)

  ## Examples

      {:ok, false} = Guardsix.failover?("https://guardsix.example.com")

  """
  @spec failover?(String.t(), keyword()) :: {:ok, boolean()} | {:error, Error.t()}
  def failover?(base_url, opts \\ []) do
    case scrape_landing_page(base_url, @failover_pattern, opts) do
      {:ok, failover_flag} -> {:ok, String.downcase(failover_flag) == "true"}
      {:error, _} = error -> error
    end
  end

  defp scrape_landing_page(base_url, pattern, opts) do
    ssl_verify = Keyword.get(opts, :ssl_verify, true)
    req = BaseClient.new(base_url, ssl_verify)

    with {:ok, %{status: 200, body: body}} <- Req.get(req),
         [_, value] <- Regex.run(pattern, body) do
      {:ok, value}
    else
      {:ok, %{status: status}} -> {:error, %Error.API{message: "expected HTTP 200, got #{status}", status: status}}
      {:error, exception} -> {:error, %Error.Transport{cause: exception}}
      nil -> {:error, %Error.API{message: "the landing page did not contain the requested value"}}
    end
  end

  defp format_version(version, :long), do: version

  defp format_version(version, :short) do
    case Regex.run(@semver_pattern, version) do
      [_, semver] -> semver
      nil -> version
    end
  end

  @doc """
  Create an authenticated session for UI endpoints that do not support JWT.

  > #### Warning {: .warning}
  >
  > This relies on internal LogPoint UI endpoints and may break if LogPoint
  > changes its login flow, CSRF handling, or page structure.

  ## Options

    * `:ssl_verify` - verify SSL certificates (default: `true`)

  ## Examples

      {:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")

  """
  @spec session(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, Guardsix.Data.Session.t()} | {:error, Error.t()}
  def session(base_url, username, password, opts \\ []) do
    Guardsix.Auth.SessionProvider.login(base_url, username, password, opts)
  end

  @doc """
  Create a client for the Guardsix API.

  ## Options

    * `:ssl_verify` - verify SSL certificates (default: `true`)

  """
  @spec client(String.t(), String.t(), String.t(), keyword()) :: Client.t()
  def client(base_url, username, secret_key, opts \\ []) do
    credential = Credential.new(username, secret_key)
    Client.new(base_url, credential, opts)
  end

  @doc """
  Build a search query.
  """
  @spec search_params(String.t(), String.t() | [number()], non_neg_integer(), [String.t()]) ::
          SearchParams.t()
  def search_params(query, time_range, limit, repos) do
    SearchParams.new(query, time_range, limit, repos)
  end

  @doc """
  Build a search query with explicit start and end times.
  """
  @spec search_params(String.t(), number(), number(), non_neg_integer(), [String.t()]) ::
          SearchParams.t()
  def search_params(query, start_time, end_time, limit, repos) do
    SearchParams.new(query, start_time, end_time, limit, repos)
  end

  @doc """
  Run a search and block until final results arrive.

  Polls automatically, handling expired searches by resubmitting the query.

  ## Options

    * `:polling_interval` — milliseconds between polls (default: `1_000`)
    * `:max_attempts`     — maximum poll iterations (default: `30`)

  """
  @spec run_search(Client.t(), SearchParams.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def run_search(%Client{} = client, %SearchParams{} = query, opts \\ []) do
    SearchRunner.run(client, query, opts)
  end

  @doc """
  Build an incident comment.
  """
  @spec comment(String.t(), String.t() | [String.t()]) :: Comment.t()
  def comment(incident_id, comments) do
    Comment.new(incident_id, comments)
  end

  @doc """
  Build an alert rule.
  """
  @spec rule(String.t()) :: Rule.t()
  def rule(name) do
    Rule.new(name)
  end

  @doc """
  Build an email notification for alert rules.
  """
  @spec email_notification([String.t()], String.t() | [String.t()]) :: EmailNotification.t()
  def email_notification(ids, emails) do
    EmailNotification.new(ids, emails)
  end

  @doc """
  Build an HTTP notification for alert rules.
  """
  @spec http_notification([String.t()], String.t(), atom()) :: HttpNotification.t()
  def http_notification(ids, url, request_type) do
    HttpNotification.new(ids, url, request_type)
  end
end
