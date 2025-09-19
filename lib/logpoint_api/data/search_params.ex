defmodule LogpointApi.Data.SearchParams do
  @moduledoc false
  @derive Jason.Encoder
  defstruct [:query, :time_range, :limit, :repos]

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

  def to_form_data(%__MODULE__{} = params) do
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
