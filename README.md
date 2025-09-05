# LogpointApi

A clean, stateless Elixir library for interacting with the [Logpoint API](https://docs.logpoint.com/docs/logpoint-api-reference/en/latest/index.html).

This library provides simple functions that make direct HTTP requests to the Logpoint API without any OTP overhead or persistent connections.

## Installation

```elixir
def deps do
  [
    {:logpoint_api, github: "MikaelFangel/logpoint_api", tag: "v1.0.0"}
  ]
end
```

## Basic Usage

All functions require credentials as the first parameter:

```elixir
# Define your credentials
credentials = %{
  ip: "127.0.0.1",
  username: "admin",
  secret_key: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  verify_ssl: false  # optional, defaults to false for self-signed certs
}
```

### Complete Search (Recommended)

The easiest way to perform a search is using `run_search/2`, which handles the entire search lifecycle:

```elixir
# Create a query
query = %LogpointApi.Query{
  query: "user=*",
  limit: 100,
  repos: ["127.0.0.1:5504"],
  time_range: [1_714_986_600, 1_715_031_000]
}

# Run the complete search (submit + poll for results)
{:ok, results} = LogpointApi.run_search(credentials, query)
```

### Manual Search Control

For more control over the search process:

```elixir
# Submit a search and get the search ID
{:ok, %{"search_id" => search_id}} = LogpointApi.get_search_id(credentials, query)

# Check the search result (may need to poll until final: true)
{:ok, result} = LogpointApi.get_search_result(credentials, search_id)
```

### Instance Information

```elixir
# Get various types of data from your Logpoint instance
{:ok, user_prefs} = LogpointApi.user_preference(credentials)
{:ok, repos} = LogpointApi.logpoint_repos(credentials)
{:ok, devices} = LogpointApi.devices(credentials)
{:ok, users} = LogpointApi.users(credentials)
```

### Incident Management

```elixir
# Get incident information
{:ok, incident} = LogpointApi.incident(credentials, "incident_obj_id", "incident_id")

# Get incidents within a time range
{:ok, incidents} = LogpointApi.incidents(credentials, 1_714_986_600, 1_715_031_000)

# Add comments to incidents
comments = %{"incident_id_1" => ["This needs attention", "Escalating to team"]}
{:ok, _result} = LogpointApi.add_comments(credentials, comments)

# Assign incidents to a user  
{:ok, _result} = LogpointApi.assign_incidents(credentials, ["incident_id_1", "incident_id_2"], "user_id")

# Update incident states
{:ok, _result} = LogpointApi.resolve_incidents(credentials, ["incident_id_1"])
{:ok, _result} = LogpointApi.close_incidents(credentials, ["incident_id_2"])
{:ok, _result} = LogpointApi.reopen_incidents(credentials, ["incident_id_3"])
```

## Query Structure

Create queries using the `Log
pointApi.Query` struct:

```elixir
%LogpointApi.Query{
  query: "your_search_query",           # String: The search query
  limit: 1000,                          # Integer: Maximum number of results
  repos: ["repo1", "repo2"],           # List: Repository names to search
  time_range: [start_time, end_time]   # List: Unix timestamps [from, to]
}
```

## SSL Configuration

For servers with self-signed certificates:

```elixir
credentials = %{
  ip: "192.168.1.100",
  username: "admin", 
  secret_key: "secret123",
  verify_ssl: false  # Disables SSL certificate verification
}
```

For production servers with valid certificates:

```elixir
credentials = %{
  ip: "logpoint.company.com",
  username: "admin",
  secret_key: "secret123",
  verify_ssl: true  # Enables SSL certificate verification
}
```

## Error Handling

All functions return `{:ok, result}` or `{:error, reason}` tuples:

```elixir
case LogpointApi.run_search(credentials, query) do
  {:ok, results} ->
    IO.puts("Found #{length(results["rows"])} results")
    
  {:error, reason} ->
    IO.puts("Search failed: #{reason}")
end
```

## Advanced Options

The `run_search/3` function accepts options for polling behavior:

```elixir
options = [
  poll_interval: 2000,  # Poll every 2 seconds (default: 1000ms)
  max_retries: 30       # Maximum polling attempts (default: 60)
]

{:ok, results} = LogpointApi.run_search(credentials, query, options)
```

## Examples

### Complete Workflow Example

```elixir
# Setup
credentials = %{
  ip: "logpoint.company.com",
  username: "admin",
  secret_key: "your_secret_key",
  verify_ssl: false
}

# Search for failed logins in the last hour
query = %LogpointApi.Query{
  query: "event_type=failed_login",
  limit: 500,
  repos: ["main_repo"],
  time_range: [System.system_time(:second) - 3600, System.system_time(:second)]
}

# Run search and handle results
case LogpointApi.run_search(credentials, query) do
  {:ok, %{"rows" => events}} ->
    IO.puts("Found #{length(events)} failed login attempts")
    
    # Get incident information
    {:ok, incidents} = LogpointApi.incidents(credentials, 
                                           System.system_time(:second) - 3600, 
                                           System.system_time(:second))
    
    # Add comments to relevant incidents
    if length(incidents["incidents"]) > 0 do
      incident_id = hd(incidents["incidents"])["_id"]
      comments = %{incident_id => ["Investigating failed logins from search"]}
      LogpointApi.add_comments(credentials, comments)
    end
    
  {:error, reason} ->
    IO.puts("Search failed: #{reason}")
end
```

## Contributing

Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
