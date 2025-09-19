defmodule LogpointApi.Data.Credential do
  @moduledoc false
  @enforce_keys [:username, :secret_key]
  defstruct [:username, :secret_key]

  def new(username, secret_key) do
    %__MODULE__{
      username: username,
      secret_key: secret_key
    }
  end
end
