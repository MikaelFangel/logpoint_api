defmodule LogpointApi.JwtToken do
  @moduledoc false
  use Joken.Config

  @valid_scopes ["search:read", "search:write", "logsource:read", "alertrules:write", "alertrules:read"]

  @impl Joken.Config
  def token_config do
    default_claims(iss: "self-signed", skip: [:aud, :jti, :nbf])
  end

  def valid_scopes, do: @valid_scopes

  defp create_signer(secret, alg \\ "HS256") do
    Joken.Signer.create(alg, secret)
  end

  def generate_token(sub, scopes, secret) do
    claims = %{
      "sub" => sub,
      "scope" => format_scopes(scopes)
    }

    with {:ok, _valid_scopes} <- validate_scopes(scopes) do
      signer = create_signer(secret)
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

  defp validate_scopes(scope) when is_binary(scope) do
    scope |> String.split(" ") |> validate_scopes()
  end

  defp validate_scopes(_), do: {:error, "Scopes must be a list or string"}

  defp format_scopes(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
  defp format_scopes(scope) when is_binary(scope), do: scope
end
