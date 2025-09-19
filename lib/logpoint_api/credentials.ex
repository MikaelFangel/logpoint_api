defmodule LogpointApi.Credentials do
  @moduledoc """
  Credentials for authenticating with the Logpoint API.

  This struct contains all the necessary information to authenticate
  with a Logpoint instance.
  """

  @type t :: %__MODULE__{
          ip: String.t(),
          username: String.t(),
          secret_key: String.t(),
          verify_ssl: boolean()
        }

  defstruct [:ip, :username, :secret_key, verify_ssl: true]

  @doc """
  Creates new credentials.

  ## Parameters

    * `ip` - The IP address or hostname of the Logpoint instance
    * `username` - The username for authentication
    * `secret_key` - The secret key for authentication
    * `verify_ssl` - Whether to verify SSL certificates (default: true)

  ## Examples

      iex> LogpointApi.Credentials.new("192.168.1.100", "admin", "secret123")
      %LogpointApi.Credentials{
        ip: "192.168.1.100",
        username: "admin",
        secret_key: "secret123",
        verify_ssl: true
      }

      iex> LogpointApi.Credentials.new("192.168.1.100", "admin", "secret123", false)
      %LogpointApi.Credentials{
        ip: "192.168.1.100",
        username: "admin",
        secret_key: "secret123",
        verify_ssl: false
      }
  """
  @spec new(String.t(), String.t(), String.t(), boolean()) :: t()
  def new(ip, username, secret_key, verify_ssl \\ true) do
    %__MODULE__{
      ip: ip,
      username: username,
      secret_key: secret_key,
      verify_ssl: verify_ssl
    }
  end
end
