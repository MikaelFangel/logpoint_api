defmodule Guardsix.Error.API do
  @moduledoc """
  Guardsix returned an error for the request.

  Returned when the API answers `success: false` without naming the offending fields. An error that
  does name them arrives as a `Guardsix.Error.Validation`, and a credential or token problem as a
  `Guardsix.Error.Auth`.

  `message` carries the vendor's own wording. `status` is the HTTP status, which is not a reliable
  signal on its own — a duplicate alert rule name is answered `200` with `success: false`. `body`
  holds the decoded response for anything this struct does not surface.
  """

  @enforce_keys [:message]
  defexception [:message, :status, :error_code, :body]

  @type t :: %__MODULE__{
          message: String.t(),
          status: non_neg_integer() | nil,
          error_code: term(),
          body: map() | nil
        }
end
