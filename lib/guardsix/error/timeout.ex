defmodule Guardsix.Error.Timeout do
  @moduledoc """
  A search did not reach final results in time.

  Returned by `Guardsix.run_search/3` when polling runs out of attempts. The search is not cancelled
  — it may still be running on the instance, and `search_id` can be polled directly with
  `Guardsix.Core.Search.get_result/2`.
  """

  @enforce_keys [:attempts]
  defexception [:attempts, :search_id]

  @type t :: %__MODULE__{
          attempts: pos_integer(),
          search_id: String.t() | nil
        }

  @impl true
  def message(%__MODULE__{attempts: attempts}) do
    "search did not return final results within #{attempts} attempts"
  end
end
