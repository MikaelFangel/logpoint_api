defmodule Guardsix.Error.Transport do
  @moduledoc """
  The request never completed, or the response could not be read.

  `cause` is the underlying exception: a `Req` transport error when the request did not complete, or
  a `Jason.DecodeError` when a response arrived but was not the JSON the API promised. For a decode
  failure, `status` and `body` carry the response that could not be parsed.
  """

  @enforce_keys [:cause]
  defexception [:cause, :status, :body]

  @type t :: %__MODULE__{
          cause: Exception.t() | term(),
          status: non_neg_integer() | nil,
          body: String.t() | nil
        }

  @impl true
  def message(%__MODULE__{cause: cause}) when is_exception(cause), do: Exception.message(cause)
  def message(%__MODULE__{cause: cause}), do: "the request failed: #{inspect(cause)}"
end
