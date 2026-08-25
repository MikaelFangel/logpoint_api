# Rules for working with Guardsix

## Architecture

Guardsix is a stateless wrapper around the Guardsix SIEM API. There is no OTP process or connection pool — every function call makes a direct HTTP request.

All API calls require a `Client` struct. Always create it through the facade:

```elixir
client = Guardsix.client("https://guardsix.company.com", "admin", "secret_key")
```

Never construct `Client`, `Credential`, or other data structs directly. Use the facade functions in `Guardsix`:
- `Guardsix.client/3,4` — client
- `Guardsix.search_params/4,5` — search query parameters
- `Guardsix.comment/2` — incident comment
- `Guardsix.rule/1` — alert rule builder
- `Guardsix.email_notification/2` — email notification builder
- `Guardsix.http_notification/3` — HTTP notification builder

## Module layout

Domain logic lives under `Guardsix.Core.*`:
- `Search` — search queries, results, instance info
- `Incident` — incident listing, state changes, comments
- `AlertRule` — alert rule CRUD, notifications (includes `update/3` and `get_notification/3`)
- `GuardsixRepo` — searchable repos
- `UserDefinedList` — user-defined lists (JWT, stable)
- `UserDefinedListBySession` — session-based list operations: extract, update, delete (unstable)

Builder structs live under `Guardsix.Data.*`:
- `Rule` — alert rule builder (pipe through setter functions, pass to `AlertRule.create/2`)
- `EmailNotification` — email notification builder
- `HttpNotification` — HTTP notification builder

Errors live under `Guardsix.Error.*`:
- `Guardsix.Error` — the union type used in every spec; a namespace, not a struct
- `Guardsix.Error.Validation`, `.API`, `.Auth`, `.Transport`, `.Timeout` — alias `Guardsix.Error` and match `%Error.Validation{}`

Do not use `Guardsix.Net.*` or `Guardsix.Auth.*` directly. These are internal.

## Return values

All API functions return `{:ok, map()}` or `{:error, Guardsix.Error.t()}`. The ok value is the decoded JSON response from the Guardsix API as a map with string keys.

Errors are one of five exception structs. Match on the struct, not on a field — each carries only what applies to it, so there are no nil fields to guard against:

- `Guardsix.Error.Validation` — the request was invalid, rejected locally or by the API. `errors` is field-keyed and never empty.
- `Guardsix.Error.API` — Guardsix returned an error for the request. `message`, `status`, `error_code`, `body`.
- `Guardsix.Error.Auth` — login, token, or scope failure. `message`, `status`.
- `Guardsix.Error.Transport` — the request did not complete or the response was unreadable. `cause` is the `Req` or `Jason` exception.
- `Guardsix.Error.Timeout` — a search did not finish within the allowed polls. `attempts`, `search_id`.

All five are exceptions, so `Exception.message/1` works on any of them and `{:error, error}` is always a safe final clause.

```elixir
case AlertRule.create(client, rule) do
  {:ok, created} -> created
  {:error, %Error.Validation{errors: fields}} -> report(fields)
  {:error, %Error.Transport{}} -> retry()
  {:error, error} -> Logger.error(Exception.message(error))
end
```

`Error.Validation` is the same struct for local and API rejections, so `Rule.validate/1` and a rejected `AlertRule.create/2` are read the same way:

```elixir
{:error, error} = Rule.validate(rule)
error.errors  # %{"query" => "is required"}

{:error, error} = AlertRule.create(client, rule)
error.errors  # %{"name" => "Alertrule with the same name already exists"}
error.status  # 422
```

Nested sections of a rule payload are flattened into dotted keys, so a rejected search interval is keyed `"search_params.search_interval_minute"`.

Do not branch on the status alone. A duplicate alert rule name is answered `200` with `success: false`, and a validation failure can be `200` or `422`. Both conventions are handled: anything outside `2xx` is an error, and so is a `2xx` carrying `success: false`. A `2xx` with an empty body (such as a `204`) is `{:ok, %{}}`.

## Search is asynchronous

Search requires two steps: submit the query, then poll for results. Use `run_search/3` for automatic polling:

```elixir
query = Guardsix.search_params("user=*", "Last 24 hours", 100, ["127.0.0.1"])
{:ok, result} = Guardsix.run_search(client, query)
```

Expired searches (`success: false`) are resubmitted automatically.

For custom polling, use the low-level primitives:

```elixir
{:ok, %{"search_id" => id}} = Search.get_id(client, query)
{:ok, result} = Search.get_result(client, id)
```

Poll `get_result/2` until `result["final"] == true`. Handle `result["success"] == false` by resubmitting with `get_id/2` to get a fresh search ID (the search expired server-side).

## Listings are paginated

`AlertRule.list/2`, `UserDefinedList.list/2` and the other `lists_api` endpoints return one page. Omitting `:page` gives you the first page and no indication that there are more, so pass `:limit` and `:page` and page until you have them all.

The response carries `total`, which is how many rules exist rather than how many were returned. Check it: a listing that is short of `total` is a partial answer that looks like a complete one.

```elixir
{:ok, %{"rows" => rows, "total" => total}} = AlertRule.list(client, %{limit: 200, page: 1})
```

`return_all_data: true` is unrelated to paging — it asks for every *field* of each rule, not every rule.

## Alert rule time ranges

`Rule.time_range/2,3` accepts a value and an optional unit (`:minute`, `:hour`, `:day`). Default unit is `:minute`. Only one time range field is sent to the API — the last call wins.

Limits: minutes 1–59, hours 1–720, days 1–30. Values outside these ranges raise `FunctionClauseError`. Minutes >= 60 auto-promote to hours, hours > 720 auto-promote to days.

```elixir
Rule.time_range(rule, 30)           # 30 minutes
Rule.time_range(rule, 12, :hour)    # 12 hours
Rule.time_range(rule, 1, :day)      # 1 day
Rule.time_range(rule, 120)          # auto-promotes to 2 hours
```

## Alert rule required fields

`Rule.validate/1` checks that these fields are set before API submission: `name`, `query`, `repos`, `threshold_option`, `threshold_value`, `risk_level`, `aggregation_type`, `assignee`, and at least one time range field.

`AlertRule.create/2` calls `validate/1` automatically.

## SSL verification

SSL verification is enabled by default. Pass `ssl_verify: false` only for self-signed certificates in isolated environments:

```elixir
client = Guardsix.client("https://192.168.1.100", "admin", "secret", ssl_verify: false)
```

## Authentication

The library handles authentication internally. Search and incident endpoints send credentials in the request body. Alert rule, repo, and list endpoints use JWT bearer tokens generated from the same credentials. You do not need to manage tokens.
