defmodule LogpointApi.Auth.JwtProvider do
  @moduledoc false
  use Joken.Config

  @valid_scopes ["search:read", "search:write", "logsource:read", "alertrules:write", "alertrules:read"]

  @impl Joken.Config
  def token_config do
    default_claims(iss: "self-signed", skip: [:aud, :jti, :nbf])
  end

  def valid_scopes, do: @valid_scopes

  @doc """
  Generate token for alert rule read operations.
  """
  def alert_rule_read_token(credential) do
    generate_token(credential, ["alertrules:read"])
  end

  @doc """
  Generate token for alert rule write operations (create, update, delete).
  """
  def alert_rule_write_token(credential) do
    generate_token(credential, ["alertrules:write"])
  end

  @doc """
  Generate token for search read operations.
  """
  def search_read_token(credential) do
    generate_token(credential, ["search:read"])
  end

  @doc """
  Generate token for search write operations.
  """
  def search_write_token(credential) do
    generate_token(credential, ["search:write"])
  end

  @doc """
  Generate token for log source read operations.
  """
  def logsource_read_token(credential) do
    generate_token(credential, ["logsource:read"])
  end

  @doc """
  Generate token with multiple scopes for complex operations.
  """
  def multi_scope_token(credential, scopes) when is_list(scopes) do
    generate_token(credential, scopes)
  end

  defp create_signer(secret, alg \\ "HS256") do
    Joken.Signer.create(alg, secret)
  end

  defp generate_token(credential, scopes) do
    claims = %{
      "sub" => credential.username,
      "scope" => format_scopes(scopes)
    }

    with {:ok, _valid_scopes} <- validate_scopes(scopes) do
      signer = create_signer(credential.secret_key)
      generate_and_sign(claims, signer)
    end
  end

  defp validate_scopes(scopes) when is_list(scopes) do
    invalid_scopes = scopes -- @valid_scopes

    case invalid_scopes do
      [] -> {:ok, scopes}
      invalid -> {:error, "Invalid scopes: #{inspect(invalid)}"}
    end
  end

  defp format_scopes(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
end
