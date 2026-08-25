defmodule Guardsix.Data.SearchParams do
  @moduledoc """
  Search query parameters passed to `Guardsix.Core.Search` functions.

  Built via `Guardsix.search_params/4,5`.
  """
  @enforce_keys [:query, :time_range, :limit, :repos]
  defstruct [:query, :time_range, :limit, :repos]

  @type t :: %__MODULE__{
          query: String.t(),
          time_range: String.t() | [number()],
          limit: non_neg_integer(),
          repos: [String.t()]
        }

  def new(query, time_range, limit, repos) do
    %__MODULE__{
      query: query,
      time_range: time_range,
      limit: limit,
      repos: repos
    }
  end

  def new(query, start_time, end_time, limit, repos) do
    %__MODULE__{
      query: query,
      time_range: [start_time, end_time],
      limit: limit,
      repos: repos
    }
  end

  def to_payload(%__MODULE__{} = params) do
    %{
      query: params.query,
      time_range: serialize_time_range(params.time_range),
      limit: params.limit,
      repos: serialize_repos(params.repos)
    }
  end

  defp serialize_time_range(time_range) when is_list(time_range), do: time_range
  defp serialize_time_range(time_range) when is_binary(time_range), do: time_range

  defp serialize_repos(repos) when is_list(repos) do
    Enum.join(repos, ",")
  end

  defp serialize_repos(repos), do: repos
end
