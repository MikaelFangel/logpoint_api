defmodule Guardsix.Data.HttpNotification do
  @moduledoc """
  Builder for HTTP notification structs.

  Wraps the [HTTP Notification for Alert Rules API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/http-notification-for-alert-rules).
  Start with `Guardsix.http_notification/3` and pipe through the builder
  functions to configure the request and auth. Supports `no_auth/1`,
  `api_token_auth/3`, `basic_auth/3`, and `bearer_auth/2`.
  """

  alias Guardsix.Error

  @derive {Inspect, except: [:auth]}
  @enforce_keys [:ids, :http_url, :http_request_type]
  defstruct [
    :ids,
    :auth,
    :http_url,
    :http_request_type,
    :http_querystring,
    :notify_http,
    :http_format_query,
    :http_body,
    :dispatch_option,
    :threshold_option,
    :threshold_value,
    http_protocol: "HTTPS"
  ]

  @type t :: %__MODULE__{
          ids: [String.t()],
          http_url: String.t(),
          http_request_type: String.t(),
          http_querystring: String.t() | nil,
          notify_http: boolean() | nil,
          http_format_query: String.t() | nil,
          http_body: String.t() | nil,
          http_protocol: String.t() | nil,
          dispatch_option: String.t() | nil,
          threshold_option: String.t() | nil,
          threshold_value: number() | nil,
          auth: map()
        }

  @required_fields [:ids, :http_url, :http_request_type]

  @spec validate(t()) :: :ok | {:error, Error.Validation.t()}
  def validate(%__MODULE__{} = notif) do
    errors =
      for field <- @required_fields,
          blank?(Map.get(notif, field)),
          into: %{},
          do: {to_string(field), "is required"}

    case errors do
      empty when map_size(empty) == 0 -> :ok
      errors -> {:error, Error.Validation.new(errors)}
    end
  end

  defp blank?(nil), do: true
  defp blank?([]), do: true
  defp blank?(_), do: false

  for {request_type_atom, request_type_string} <- [
        get: "GET",
        post: "POST",
        put: "PUT",
        patch: "PATCH",
        delete: "DELETE"
      ] do
    def new(ids, url, unquote(request_type_atom)) when is_list(ids) and is_binary(url) do
      %__MODULE__{
        ids: ids,
        http_url: url,
        http_request_type: unquote(request_type_string)
      }
    end
  end

  def querystring(%__MODULE__{} = notif, qs), do: %{notif | http_querystring: qs}
  def notify_http(%__MODULE__{} = notif, enabled), do: %{notif | notify_http: enabled}
  def format_query(%__MODULE__{} = notif, format), do: %{notif | http_format_query: format}
  def body(%__MODULE__{} = notif, body), do: %{notif | http_body: body}
  def protocol(%__MODULE__{} = notif, protocol), do: %{notif | http_protocol: protocol}
  def dispatch_option(%__MODULE__{} = notif, option), do: %{notif | dispatch_option: option}

  def no_auth(%__MODULE__{} = notif) do
    %{notif | auth: %{auth_type: "None"}}
  end

  def api_token_auth(%__MODULE__{} = notif, key, value) do
    %{notif | auth: %{auth_type: "api_token", auth_key: key, auth_value: value}}
  end

  def basic_auth(%__MODULE__{} = notif, username, password) do
    %{notif | auth: %{auth_type: "basic_auth", auth_key: username, auth_pass: password}}
  end

  def bearer_auth(%__MODULE__{} = notif, token) do
    %{notif | auth: %{auth_type: "bearer_token", auth_key: token}}
  end

  def threshold(%__MODULE__{} = notif, option, value) when is_atom(option) do
    %{notif | threshold_option: Atom.to_string(option), threshold_value: value}
  end

  @doc """
  Convert an `HttpNotification` struct into the flat map format expected by the Guardsix API.
  """
  def to_payload(%__MODULE__{} = notif) do
    %{
      ids: notif.ids,
      http_url: notif.http_url,
      http_request_type: notif.http_request_type,
      http_querystring: notif.http_querystring || "",
      notify_http: notif.notify_http,
      http_format_query: notif.http_format_query,
      http_body: notif.http_body,
      protocol: notif.http_protocol,
      dispatch_option: notif.dispatch_option,
      http_header: unwrap_header(notif.auth),
      http_threshold_option: notif.threshold_option,
      http_threshold_value: notif.threshold_value
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp unwrap_header(nil), do: nil
  defp unwrap_header(header), do: Jason.encode!(header)
end
