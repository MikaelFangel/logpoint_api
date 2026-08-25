defmodule Guardsix.Error do
  @moduledoc """
  The error types returned by this library.

  Every function that talks to a Guardsix instance answers `{:ok, term()}` or `{:error, t()}`, where
  `t()` is one of five exception structs. Match on the struct to tell them apart:

      alias Guardsix.Error

      case AlertRule.create(client, rule) do
        {:ok, created} -> created
        {:error, %Error.Validation{errors: fields}} -> report(fields)
        {:error, %Error.Transport{}} -> retry()
        {:error, error} -> Logger.error(Exception.message(error))
      end

  Each type carries only the fields that apply to it, so there are no `nil`s to guard against on the
  fields you match on. All five are exceptions, which means `Exception.message/1` works on any of
  them and the last clause above is a complete fallback — and any of them can be raised if you would
  rather let it crash.

    * `Guardsix.Error.Validation` — the request was invalid, rejected here or at the API
    * `Guardsix.Error.API` — Guardsix returned an error for the request
    * `Guardsix.Error.Auth` — login, token, or scope failure
    * `Guardsix.Error.Transport` — the request did not complete, or the response was unreadable
    * `Guardsix.Error.Timeout` — a search did not finish within the allowed attempts

  """

  alias Guardsix.Error.API
  alias Guardsix.Error.Auth
  alias Guardsix.Error.Timeout
  alias Guardsix.Error.Transport
  alias Guardsix.Error.Validation

  @type t ::
          API.t()
          | Auth.t()
          | Timeout.t()
          | Transport.t()
          | Validation.t()

  @doc false
  @spec from_response(map(), non_neg_integer() | nil) :: t()
  def from_response(body, status) when is_map(body) do
    status = resolve_status(body, status)
    errors = validation_errors(body)

    cond do
      map_size(errors) > 0 ->
        %Validation{errors: errors, status: status, body: body}

      auth?(body, status) ->
        %Auth{message: message(body), status: status, body: body}

      true ->
        %API{message: message(body), status: status, error_code: Map.get(body, "error_code"), body: body}
    end
  end

  defp validation_errors(body) do
    case Map.get(body, "validationErrors") do
      nested when is_map(nested) -> flatten(nested)
      _absent -> detail_errors(Map.get(body, "detail"))
    end
  end

  defp detail_errors(entries) when is_list(entries) do
    entries
    |> Enum.filter(&is_map/1)
    |> Map.new(fn entry -> {location(entry), Map.get(entry, "msg") || "is invalid"} end)
  end

  defp detail_errors(_absent), do: %{}

  defp location(%{"loc" => [_ | _] = loc}), do: Enum.map_join(loc, ".", &to_string/1)
  defp location(_entry), do: "request"

  defp auth?(body, status), do: token_failure?(body) or status in [401, 403]

  defp token_failure?(body), do: is_binary(Map.get(body, "error")) and not is_binary(Map.get(body, "message"))

  # Token failures report the status in the body as well as in the response.
  defp resolve_status(body, status), do: status || Map.get(body, "status_code")

  defp message(body) do
    Map.get(body, "message") || Map.get(body, "error") || detail_message(Map.get(body, "detail")) ||
      "the request failed"
  end

  defp detail_message(detail) when is_binary(detail), do: detail
  defp detail_message(_other), do: nil

  defp flatten(errors) when is_map(errors), do: errors |> Enum.flat_map(&entries/1) |> Map.new()
  defp flatten(_absent), do: %{}

  defp entries({field, nested}) when is_map(nested) do
    nested |> flatten() |> Enum.map(fn {inner, message} -> {"#{field}.#{inner}", message} end)
  end

  defp entries({field, message}), do: [{field, message}]
end
