defmodule LogpointApi do
  @moduledoc false

  defmodule Credential do
    @typedoc """
    Struct representing credentials used for authorization.
    """
    @type t :: %__MODULE__{username: String.t(), secret_key: String.t()}
    defstruct [:username, :secret_key]
  end
end
