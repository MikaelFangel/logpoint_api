defmodule LogpointApi do
  @moduledoc false

  defmodule Credential do
    @moduledoc """
    Struct representing credentials used for authorization.
    """
    defstruct [:username, :secret_key]
  end
end
