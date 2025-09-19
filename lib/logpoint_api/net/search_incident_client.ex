defmodule LogpointApi.Net.SearchIncidentClient do
  @moduledoc false

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

  def get(req, path, credential, body \\ %{}) do
    body = body_with_credential(credential, body)
    Req.get(req, url: path, json: body)
  end

  def post(req, path, credential, body, content_type) when content_type in [:json, :form] do
    request_body = body_with_credential(credential, body)

    case content_type do
      :json ->
        Req.post(req, url: path, json: request_body)

      :form ->
        Req.post(req, url: path, form: request_body)
    end
  end

  def post_json(req, path, credential, body) do
    post(req, path, credential, body, :json)
  end

  def post_form(req, path, credential, body) do
    post(req, path, credential, body, :form)
  end

  defp body_with_credential(%LogpointApi.Data.Credential{username: username, secret_key: secret}, body) do
    Map.merge(%{username: username, secret_key: secret}, body)
  end
end
