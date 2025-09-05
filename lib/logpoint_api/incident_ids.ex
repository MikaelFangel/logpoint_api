defmodule LogpointApi.IncidentIDs do
  @moduledoc false
  @typedoc """
  Struct that represents a list of incidents.
  """
  @type t :: %__MODULE__{version: String.t(), incident_ids: list()}
  @derive {Jason.Encoder, only: [:version, :incident_ids]}
  defstruct version: "0.1", incident_ids: []

  @spec new(String.t(), [String.t()]) :: t()
  def new(version \\ "0.1", incident_ids \\ []) do
    %__MODULE__{version: version, incident_ids: incident_ids}
  end
end
