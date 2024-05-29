# LogpointApi

Elixir library implementing the [Logpoint API reference](https://docs.logpoint.com/docs/logpoint-api-reference/en/latest/index.html).

## Installation

```elixir
def deps do
  [
    {:logpoint_api, github: "MikaelFangel/logpoint_api", tag: "v0.2.1"}
  ]
end
```

## Example Usage

Examples on how to use the library where all examples assumes the following variables are set:

```elixir
ip = "127.0.0.1"

creds = %LogpointApi.Credential{
  username: "admin",
  secret_key: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
}
```

It's expected that you have included this repo into your mix project (see installation). Furthermore, module definitions, docs, and so forth have been excluded from the examples for brevity.

### Run Search

This will create a search_id and then retrieve and return the result.

```elixir
query = LogpointApi.SearchApi.Query{
  query: "user=*",
  limit: 100,
  repos: ["127.0.0.1:5504"],
  time_range [1_714_986_600, 1_715_031_000]
}

LogpointApi.run_search(ip, creds, query)
```

### Get a Search ID

This will create the search and return its id if successfull.

```elixir
query = LogpointApi.SearchApi.Query{
  query: "user=*",
  limit: 100,
  repos: ["127.0.0.1:5504"],
  time_range [1_714_986_600, 1_715_031_000]
}

LogpointApi.IncidentApi.get_search_id(ip, creds, query)
```

### Retrieve a Search from a Search ID

This will retrieve the result of a given search ID. Be aware if the _final_ key in the result map is `false` the search hasn't completed yet, and you need to fetch again. Otherwise, if the key _success_ is `false` you need to recreate the search and try to retrieve it again.

```elixir
LogpointApi.IncidentApi.get_search_result(ip, creds, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
```
