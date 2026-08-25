# Polling for Search Results

The Guardsix search API is asynchronous — you submit a query and then poll
until results are ready. `run_search/3` handles the polling loop so you
don't have to write one yourself.

## Usage

```elixir
client = Guardsix.client("https://guardsix.company.com", "admin", "secret")
query = Guardsix.search_params("user=*", "Last 24 hours", 100, ["127.0.0.1:5504"])

{:ok, result} = Guardsix.run_search(client, query)
```

Customize the poll interval and maximum attempts:

```elixir
{:ok, result} = Guardsix.run_search(client, query, polling_interval: 2_000, max_attempts: 15)
```

Returns `{:error, %Guardsix.Error.Timeout{}}` if the search doesn't complete in time. The search
is not cancelled — the error carries the `search_id`, so you can keep polling it yourself with
`Search.get_result/2`.

## Running in the background

Wrap `run_search/2` in a `Task` or `Task.Supervisor` yourself:

```elixir
task = Task.async(fn -> Guardsix.run_search(client, query) end)
{:ok, result} = Task.await(task, 120_000)
```

## Expired search handling

`run_search/3` handles the case where Guardsix expires a search
(the API returns `"success" => false`). When this happens, the original
query is resubmitted automatically to get a fresh search ID.

## Custom polling

If the built-in polling doesn't fit your needs, use the low-level
primitives directly:

```elixir
alias Guardsix.Core.Search

{:ok, %{"search_id" => search_id}} = Search.get_id(client, query)

# Poll in your own loop, GenServer, etc.
{:ok, result} = Search.get_result(client, search_id)
```

The key detail is the `success: false` handling — Guardsix can expire a search,
so your poller should resubmit the original query via `Search.get_id/2` to get
a new search ID and keep going.
