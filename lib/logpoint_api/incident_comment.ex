defmodule LogpointApi.IncidentComment do
  @moduledoc false
  @typedoc """
  Struct to add comments to a particular incident.
  """
  @type t :: %__MODULE__{_id: String.t(), comments: list()}
  @derive {Jason.Encoder, only: [:_id, :comments]}
  defstruct _id: "", comments: []

  @spec new(String.t(), [String.t()]) :: t()
  def new(id, comments \\ []) do
    %__MODULE__{_id: id, comments: comments}
  end
end
