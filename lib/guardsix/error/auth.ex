defmodule Guardsix.Error.Auth do
  @moduledoc """
  Authentication or authorization failed.

  Covers the browser-session login flow behind `Guardsix.session/4`, JWT signing and scope problems,
  and tokens the API turns down — expired, wrong scope, or not self-signed.

  `status` is the HTTP status when the failure came back in a response, and `nil` when the token was
  rejected before a request was ever made.
  """

  @enforce_keys [:message]
  defexception [:message, :status, :body]

  @type t :: %__MODULE__{
          message: String.t(),
          status: non_neg_integer() | nil,
          body: map() | nil
        }
end
