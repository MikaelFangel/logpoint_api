# Guardsix

> [!NOTE]
> This package was previously published as `logpoint_api` and has been renamed to `guardsix` following the company rebranding.

A stateless implementation of the [Guardsix SIEM API Reference](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference).
The library is a wrapper around the API reference with the addition of builder patterns for alert rules and notifications. I try
to make sure the library stays as true to the API as possible with minor simplifications so it is easier to correlate the lib with
the API reference doc.

## Installation

```elixir
def deps do
  [
    {:guardsix, "~> 2.0"}
  ]
end
```

## Basic Usage

Create a universal client that can be used with all functions. This is a simplification over the split in the API design
where some endpoints use JWT tokens and others don't.

```elixir
client = Guardsix.client("https://guardsix.company.com", "admin", "your_secret_key")
```

### Search

Search includes all functions from the [search API reference](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/search-api) and for writing search_param queries please refer to [Search Log Data](https://docs.guardsix.com/siem/product-docs/readme/a_work-with-your-log-data/search_your_log_data).

```elixir
alias Guardsix.Core.Search

query = Guardsix.search_params(
  "user=*",
  "Last 24 hours",
  100,
  ["127.0.0.1:5504"]
)

{:ok, %{"search_id" => search_id}} = Search.get_id(client, query)
{:ok, result} = Search.get_result(client, search_id)
```

### Instance Information

```elixir
alias Guardsix.Core.Search

{:ok, user_prefs} = Search.user_preference(client)
{:ok, repos}      = Search.repos(client)
{:ok, devices}    = Search.devices(client)
```

### Incident Management

The incident module wraps the [Incident API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/incident-api).

```elixir
alias Guardsix.Core.Incident

# List incidents within a time range
{:ok, incidents} = Incident.list(client, 1_714_986_600, 1_715_031_000)
{:ok, states}    = Incident.list_states(client, 1_714_986_600, 1_715_031_000)

# Get a specific incident where both the incident_obj_id and incident_id
# is needed to get the unique incident.
{:ok, incident} = Incident.get(client, "incident_obj_id", "incident_id")

# Add comments
comments = [Guardsix.comment("incident_id_1", "This needs attention")]
{:ok, _} = Incident.add_comments(client, comments)

# Assign and update states
{:ok, _} = Incident.assign(client, ["incident_id_1"], "user_id")
{:ok, _} = Incident.resolve(client, ["incident_id_1"])
{:ok, _} = Incident.close(client, ["incident_id_2"])
{:ok, _} = Incident.reopen(client, ["incident_id_3"])

# Get users
{:ok, users} = Incident.get_users(client)
```

### Alert Rules

AlertRule wraps the [Alert Rules API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/alert_rules_api).
All parameters for alert rule creation are defined but please refer to the alert rule builder for a composable structure
for building rules.

```elixir
alias Guardsix.Core.AlertRule

{:ok, rules} = AlertRule.list(client)
{:ok, rule}  = AlertRule.get(client, "rule-id")
{:ok, _}     = AlertRule.activate(client, ["id1", "id2"])
{:ok, _}     = AlertRule.deactivate(client, ["id1"])
{:ok, _}     = AlertRule.delete(client, ["id1"])
{:ok, notif} = AlertRule.get_notification(client, "rule-id", :email)
```

#### Alert Rule Builder

Compose alert rules to be used with the create alert rule endpoint.

```elixir
alias Guardsix.Data.Rule

rule =
  Guardsix.rule("Brute Force Detection")
  |> Rule.description("Detects brute force login attempts")
  |> Rule.query("error_code=4625")
  |> Rule.time_range(1, :day)
  |> Rule.repos(["10.0.0.1"])
  |> Rule.limit(100)
  |> Rule.threshold(:greaterthan, 5)
  |> Rule.risk_level("high")
  |> Rule.mitre_tags(["T1110"])

{:ok, _} = AlertRule.create(client, rule)
```

#### Notification Builders

Compose notifications for alert rules.

```elixir
alias Guardsix.Data.EmailNotification
alias Guardsix.Data.HttpNotification

# Email notification
notif =
  Guardsix.email_notification(["rule-1"], "admin@example.com")
  |> EmailNotification.subject("Alert: {{ rule_name }}")
  |> EmailNotification.template("<p>Details</p>")

{:ok, _} = AlertRule.create_email_notification(client, notif)

# HTTP notification with bearer auth
webhook =
  Guardsix.http_notification(["rule-1"], "https://hooks.slack.com/abc", :post)
  |> HttpNotification.body(~s({"text": "{{ rule_name }}"}))
  |> HttpNotification.bearer_auth("my-token")

{:ok, _} = AlertRule.create_http_notification(client, webhook)

# Other auth types: no_auth/1, api_token_auth/3, basic_auth/3
webhook
|> HttpNotification.api_token_auth("X-API-Key", "secret123")
|> HttpNotification.basic_auth("user", "pass")
```

### Guardsix Repos and User-Defined Lists

```elixir
alias Guardsix.Core.GuardsixRepo
alias Guardsix.Core.UserDefinedList

{:ok, repos} = GuardsixRepo.list(client)
{:ok, lists} = UserDefinedList.list(client)
```

#### Session-Based List Operations

Some user-defined list operations require a browser session since they are not available
via the JWT API. These are in a separate module and are **unstable**.

```elixir
alias Guardsix.Core.UserDefinedListBySession

{:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")

{:ok, data} = UserDefinedListBySession.extract(session, "list-id")
{:ok, _} = UserDefinedListBySession.update_static(session, "list-id", ["val1", "val2"])
{:ok, _} = UserDefinedListBySession.delete(session, "list-id")

# By-name variants (case-insensitive lookup)
{:ok, _} = UserDefinedListBySession.update_static_by_name(session, "MY_LIST", ["val1"])
{:ok, _} = UserDefinedListBySession.delete_by_name(session, "MY_LIST")
```

## SSL Configuration

Pass `ssl_verify: false` to disable SSL verification (e.g. for self-signed certificates):

```elixir
client = Guardsix.client("https://192.168.1.100", "admin", "your_secret_key", ssl_verify: false)
```

## Error Handling

All functions return `{:ok, result}` or `{:error, error}`, where the error is one of five exception structs. Match on the
struct to tell them apart:

```elixir
alias Guardsix.Core.AlertRule
alias Guardsix.Error

case AlertRule.create(client, rule) do
  {:ok, created} ->
    created

  {:error, %Error.Validation{errors: fields}} ->
    IO.puts("rejected: #{inspect(fields)}")

  {:error, %Error.Transport{}} ->
    retry()

  {:error, error} ->
    IO.puts(Exception.message(error))
end
```

Each type carries only the fields that apply to it, so there is nothing to nil-check on the fields you match on. All
five are exceptions, which means `Exception.message/1` works on any of them — the last clause above is a complete
fallback — and any of them can be raised if you would rather let it crash.

| Error | Returned when | Carries |
| --- | --- | --- |
| `Guardsix.Error.Validation` | The request was invalid, rejected here or at the API | `errors`, plus `status` and `body` for API rejections |
| `Guardsix.Error.API` | Guardsix returned an error for the request | `message`, `status`, `error_code`, `body` |
| `Guardsix.Error.Auth` | Login, token, or scope failure | `message`, `status` |
| `Guardsix.Error.Transport` | The request did not complete, or the response was unreadable | `cause` — the `Req` or `Jason` exception |
| `Guardsix.Error.Timeout` | A search did not finish within the allowed polls | `attempts`, `search_id` |

### Validation errors

`Error.Validation` is the same struct whether the rejection happened here — before anything is sent — or at the API, so
field complaints are read from the same place either way:

```elixir
{:error, error} = Rule.validate(rule)
error.errors  # %{"query" => "is required", "repos" => "is required"}

{:error, error} = AlertRule.create(client, rule)
error.errors  # %{"name" => "Alertrule with the same name already exists"}
error.status  # 422
```

Nested sections of an alert rule payload are flattened into dotted keys, so a rejected search interval is reported under
`"search_params.search_interval_minute"`.

Do not branch on the status alone: a duplicate alert rule name is answered `200` with `success: false`, and a validation
failure can be either `200` or `422`.

## Contributing

Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
