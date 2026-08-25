defmodule Guardsix.Net.BaseClient do
  @moduledoc false

  alias Guardsix.Error

  def new(base_url, ssl_verify \\ true) do
    base_options = [base_url: base_url]

    options =
      if ssl_verify do
        base_options
      else
        base_options ++
          [
            connect_options: [
              transport_opts: [
                verify: :verify_none
              ]
            ]
          ]
      end

    Req.new(options)
  end

  # A 204 (or any other empty success) carries no body to decode.
  def decode_response({:ok, %Req.Response{status: status, body: ""}}) when status in 200..299, do: {:ok, %{}}

  def decode_response({:ok, %Req.Response{status: status, body: body}}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> check_success(decoded, status)
      {:error, exception} -> {:error, undecodable(exception, status, body)}
    end
  end

  def decode_response({:ok, %Req.Response{status: status, body: body}}) when is_map(body),
    do: check_success(body, status)

  def decode_response({:error, exception}), do: {:error, %Error.Transport{cause: exception}}

  # The two API generations disagree about how a failure is reported. The older endpoints answer 200
  # with `success: false`; the /api/v1 endpoints have no such flag and use the status code instead.
  defp check_success(body, status) when status >= 400, do: {:error, Error.from_response(body, status)}
  defp check_success(%{"success" => false} = body, status), do: {:error, Error.from_response(body, status)}
  defp check_success(body, _status), do: {:ok, body}

  defp undecodable(_exception, status, _body) when status >= 400 do
    %Error.API{message: "the server returned HTTP #{status}", status: status}
  end

  defp undecodable(exception, status, body) do
    %Error.Transport{cause: exception, status: status, body: body}
  end
end
