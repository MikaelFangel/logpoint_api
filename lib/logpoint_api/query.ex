defmodule LogpointApi.Query do
  @moduledoc false
  @typedoc """
  Struct representing a Logpoint search query.
  """
  @type t :: %__MODULE__{
          query: String.t(),
          time_range: list() | String.t(),
          limit: non_neg_integer(),
          repos: list()
        }
  @derive {Jason.Encoder, only: [:query, :time_range, :limit, :repos]}
  defstruct [:query, :time_range, :limit, :repos]

  @spec new(String.t(), list() | String.t(), non_neg_integer(), list()) :: t()
  def new(query, time_range, limit, repos) do
    %__MODULE__{
      query: query,
      time_range: time_range,
      limit: limit,
      repos: repos
    }
  end
end
