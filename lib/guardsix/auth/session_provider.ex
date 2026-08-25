defmodule Guardsix.Auth.SessionProvider do
  @moduledoc """
  Establishes an authenticated browser session with a Guardsix instance.

  Used for UI endpoints that do not support JWT authentication. This works by
  scraping the landing page for CSRF tokens and session cookies, then logging
  in via the same form the browser uses. This approach is **unstable** and may
  break if LogPoint changes its login flow or page structure.
  """

  alias Guardsix.Data.Session
  alias Guardsix.Error
  alias Guardsix.Net.BaseClient

  @csrf_pattern ~r/CSRFToken\s*=\s*"([^"]+)"/
  @session_pattern ~r/session=([^;]+)/
  @expires_pattern ~r/Expires=([^;]+)/
  @session_ttl_seconds 24 * 60 * 60
  @browser_user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

  @spec login(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, Session.t()} | {:error, Error.t()}
  @default_auth_method "LogpointAuthentication"

  @doc """
  Login as a user and get the session as a logged in user. This has currently only been tested with LogpointAuthentication as the auth method.
  """
  def login(base_url, username, password, opts \\ []) do
    ssl_verify = Keyword.get(opts, :ssl_verify, true)
    auth_method = Keyword.get(opts, :auth_method, @default_auth_method)

    req =
      base_url
      |> BaseClient.new(ssl_verify)
      |> Req.merge(headers: [{"user-agent", @browser_user_agent}])

    with {:ok, %{body: body, headers: headers}} <- fetch_page(req),
         {:ok, csrf_token} <- extract_csrf_token(body),
         {:ok, req} <- attach_session_cookie(req, headers),
         {:ok, expires_at} <- authenticate(req, username, password, csrf_token, auth_method),
         {:ok, %{body: post_login_body}} <- fetch_page(req),
         {:ok, post_login_csrf} <- extract_csrf_token(post_login_body) do
      {:ok,
       %Session{
         req: req,
         csrf_token: post_login_csrf,
         username: username,
         expires_at: expires_at
       }}
    end
  end

  defp fetch_page(req) do
    case Req.get(req) do
      {:ok, %{status: 200} = response} -> {:ok, response}
      {:ok, %{status: status}} -> {:error, %Error.Auth{message: "expected HTTP 200, got #{status}", status: status}}
      {:error, exception} -> {:error, %Error.Transport{cause: exception}}
    end
  end

  defp extract_csrf_token(body) do
    case Regex.run(@csrf_pattern, body, capture: :all_but_first) do
      [token] -> {:ok, token}
      nil -> {:error, %Error.Auth{message: "no CSRF token on the landing page"}}
    end
  end

  defp authenticate(req, username, password, csrf_token, auth_method) do
    body = %{
      requestType: "formsubmit",
      id: "",
      username: username,
      password: password,
      url_hash: "",
      CSRFToken: csrf_token
    }

    login_path = "/pluggables/Authentication/#{auth_method}/login"

    with {:ok, %{status: 200, body: resp_body, headers: headers}} <-
           Req.post(req, url: login_path, form: body, redirect: false),
         {:ok, %{"success" => true}} <- Jason.decode(resp_body) do
      {:ok, parse_expires(headers)}
    else
      {:ok, %{"success" => false, "message" => msg}} when msg in ["", nil] ->
        {:error, %Error.Auth{message: "login failed: invalid credentials"}}

      {:ok, %{"message" => message}} ->
        {:error, %Error.Auth{message: message}}

      {:ok, %{status: status}} ->
        {:error, %Error.Auth{message: "login failed with status #{status}", status: status}}

      {:error, exception} ->
        {:error, %Error.Transport{cause: exception}}

      _unexpected ->
        {:error, %Error.Auth{message: "could not parse the login response"}}
    end
  end

  defp parse_expires(headers) do
    case find_cookie(headers, @expires_pattern) do
      nil -> default_expires()
      [expires_str] -> parse_http_date(expires_str)
    end
  end

  defp parse_http_date(nil), do: nil

  defp parse_http_date([date_string]), do: parse_http_date(date_string)

  defp parse_http_date(date_string) when is_binary(date_string) do
    case :httpd_util.convert_request_date(String.to_charlist(date_string)) do
      {{year, month, day}, {hour, min, sec}} ->
        {:ok, ndt} = NaiveDateTime.new(year, month, day, hour, min, sec)
        DateTime.from_naive!(ndt, "Etc/UTC")

      :bad_date ->
        nil
    end
  end

  defp default_expires, do: DateTime.shift(DateTime.utc_now(), second: @session_ttl_seconds)

  defp attach_session_cookie(req, headers) do
    case find_cookie(headers, @session_pattern) do
      nil -> {:error, %Error.Auth{message: "no session cookie in the login response"}}
      session -> {:ok, Req.merge(req, headers: [{"cookie", "session=#{session}"}])}
    end
  end

  defp find_cookie(headers, pattern) do
    Enum.find_value(headers, fn
      {"set-cookie", values} ->
        values
        |> List.wrap()
        |> Enum.find_value(&Regex.run(pattern, &1, capture: :all_but_first))

      _ ->
        nil
    end)
  end
end
