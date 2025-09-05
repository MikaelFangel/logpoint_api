defmodule LogpointApi.IncidentCommentData do
  @moduledoc false
  @typedoc """
  Struct to add comments to a list of incidents using the `IncidentComment` struct.
  """
  @type t :: %__MODULE__{version: String.t(), states: list()}
  @derive {Jason.Encoder, only: [:version, :states]}
  defstruct version: "0.1", states: []

  @spec new(String.t(), [LogpointApi.IncidentComment.t()]) :: t()
  def new(version \\ "0.1", states \\ []) do
    %__MODULE__{version: version, states: states}
  end
end
