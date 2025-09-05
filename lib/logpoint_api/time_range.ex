defmodule LogpointApi.TimeRange do
  @moduledoc false
  @typedoc """
  Struct representing a time range with timestamps in epoch.
  """
  @type t :: %__MODULE__{ts_from: number(), ts_to: number(), version: String.t()}
  @derive {Jason.Encoder, only: [:version, :ts_from, :ts_to]}
  defstruct [:ts_from, :ts_to, version: "0.1"]

  @spec new(number(), number(), String.t()) :: t()
  def new(ts_from, ts_to, version \\ "0.1") do
    %__MODULE__{ts_from: ts_from, ts_to: ts_to, version: version}
  end
end
