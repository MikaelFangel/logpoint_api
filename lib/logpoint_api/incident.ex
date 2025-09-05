defmodule LogpointApi.Incident do
  @moduledoc false
  @typedoc """
  Struct used to fetch an incident.
  """
  @type t :: %__MODULE__{incident_obj_id: String.t(), incident_id: String.t()}
  @derive {Jason.Encoder, only: [:incident_obj_id, :incident_id]}
  defstruct [:incident_obj_id, :incident_id]

  @spec new(String.t(), String.t()) :: t()
  def new(incident_obj_id, incident_id) do
    %__MODULE__{incident_obj_id: incident_obj_id, incident_id: incident_id}
  end
end
