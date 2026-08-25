defmodule Guardsix.Error.Validation do
  @moduledoc """
  A request was rejected as invalid.

  The same struct whether the rejection happened here — `Guardsix.Data.Rule.validate/1` and its
  siblings, before anything leaves the machine — or at the API. `errors` is keyed by field and is
  never empty, so a caller reads the same place regardless of who did the rejecting.

  Nested sections of an alert rule payload are flattened into dotted keys, so a rejected search
  interval is reported under `"search_params.search_interval_minute"`.

  `status` and `body` are populated only for rejections that came back from the API. Note that the
  status is not a reliable signal: a validation failure can be answered `200` or `422`.
  """

  @enforce_keys [:errors]
  defexception [:status, :body, errors: %{}]

  @type t :: %__MODULE__{
          errors: %{String.t() => String.t()},
          status: non_neg_integer() | nil,
          body: map() | nil
        }

  @doc """
  Build a validation error from a field-keyed map of complaints.

  ## Examples

      Error.Validation.new(%{"name" => "is required"})
      Error.Validation.new(%{"name" => "already exists"}, status: 422, body: body)

  """
  @spec new(%{String.t() => String.t()}, keyword()) :: t()
  def new(errors, opts \\ []) when is_map(errors) and map_size(errors) > 0 do
    %__MODULE__{errors: errors, status: Keyword.get(opts, :status), body: Keyword.get(opts, :body)}
  end

  @impl true
  def message(%__MODULE__{errors: errors}) do
    detail = Enum.map_join(Enum.sort(errors), ", ", fn {field, complaint} -> "#{field}: #{complaint}" end)

    "invalid request (#{detail})"
  end
end
