defmodule Guardsix.Core.UserDefinedListBySession do
  @moduledoc """
  Session-based operations for user-defined lists in Guardsix.

  These functions use session-based authentication by mimicking browser requests
  against internal LogPoint UI endpoints. They are **unstable** and may break if
  LogPoint changes its login flow, CSRF handling, or internal form fields.

  For stable JWT-based operations, use `Guardsix.Core.UserDefinedList`.
  """

  alias Guardsix.Data.Session
  alias Guardsix.Error
  alias Guardsix.Net.BaseClient

  @doc """
  Extract the contents of a user-defined list by ID.

  ## Examples

      {:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")
      UserDefinedListSession.extract(session, "69c1119e549c866b966d0959")

  """
  @spec extract(Session.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def extract(%Session{} = session, id) when is_binary(id) do
    with true <- not Session.expired?(session),
         {:ok, %{"data" => _data}} = response <-
           BaseClient.decode_response(
             Req.post(session.req, url: "/UserDefinedList/extract", form: session_fields(session, %{id: id}))
           ) do
      response
    else
      {:ok, response} ->
        {:error, %Error.API{message: "the response did not contain list data", body: response}}

      false ->
        {:error, %Error.Auth{message: "the session has expired"}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Update a static list by ID.

  Fetches the current list state, replaces the values, and saves.

  ## Examples

      {:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")
      UserDefinedListSession.update_static(session, "69c1...", ["val1", "val2"])

  """
  @spec update_static(Session.t(), String.t(), [String.t()]) :: {:ok, map()} | {:error, Error.t()}
  def update_static(%Session{} = session, id, values) when is_binary(id) and is_list(values) do
    case extract(session, id) do
      {:ok, %{"data" => data}} ->
        body = session_fields(session, build_update_body(id, data, values))
        BaseClient.decode_response(Req.post(session.req, url: "/UserDefinedList/create", form: body))

      error ->
        error
    end
  end

  @doc """
  Delete a user-defined list by ID.

  ## Examples

      {:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")
      UserDefinedListSession.delete(session, "69c1119e549c866b966d0959")

  """
  @spec delete(Session.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete(%Session{} = session, id) when is_binary(id) do
    if Session.expired?(session) do
      {:error, %Error.Auth{message: "the session has expired"}}
    else
      # id is sent in both the query string and form body to match the LogPoint UI behavior
      BaseClient.decode_response(
        Req.post(session.req,
          url: "/UserDefinedList/delete?id=#{id}",
          form: session_fields(session, %{id: id})
        )
      )
    end
  end

  @doc """
  Update a static list by name.

  Looks up the list ID by name (case-insensitive, since LogPoint uppercases names),
  then delegates to `update_static/3`.

  ## Examples

      {:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")
      UserDefinedListSession.update_static_by_name(session, "MY_LIST", ["val1", "val2"])

  """
  @spec update_static_by_name(Session.t(), String.t(), [String.t()]) ::
          {:ok, map()} | {:error, Error.t()}
  def update_static_by_name(%Session{} = session, name, values) when is_binary(name) and is_list(values) do
    case find_id_by_name(session, name) do
      {:ok, id} -> update_static(session, id, values)
      {:error, _} = error -> error
    end
  end

  @doc """
  Delete a user-defined list by name.

  Looks up the list ID by name (case-insensitive, since LogPoint uppercases names),
  then delegates to `delete/2`.

  ## Examples

      {:ok, session} = Guardsix.session("https://guardsix.example.com", "admin", "password")
      UserDefinedListSession.delete_by_name(session, "MY_LIST")

  """
  @spec delete_by_name(Session.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def delete_by_name(%Session{} = session, name) when is_binary(name) do
    case find_id_by_name(session, name) do
      {:ok, id} -> delete(session, id)
      {:error, _} = error -> error
    end
  end

  defp find_id_by_name(%Session{} = session, name) do
    with true <- not Session.expired?(session),
         {:ok, %{"rows" => rows}} <- list(session),
         %{"id" => id} <- Enum.find(rows, fn entry -> String.upcase(entry["name"] || "") == String.upcase(name) end) do
      {:ok, id}
    else
      nil -> {:error, %Error.API{message: "list not found: #{name}"}}
      false -> {:error, %Error.Auth{message: "the session has expired"}}
      {:error, _} = error -> error
      _unexpected -> {:error, %Error.API{message: "could not read the lists while looking up #{name}"}}
    end
  end

  defp list(%Session{} = session) do
    body = session_fields(session, %{limit: false, return_all_data: true})

    BaseClient.decode_response(Req.post(session.req, url: "/UserDefinedList/lists", form: body))
  end

  @update_defaults %{
    "list_type" => "static_list",
    "s_name" => "",
    "lists_vendor" => "",
    "d_name" => "",
    "source_type" => "DynamicList",
    "source_id" => "",
    "agelimit_day" => "0",
    "agelimit_hour" => "0",
    "agelimit_minute" => "30",
    "agelimit_second" => "0"
  }

  defp build_update_body(id, data, values) do
    data = Map.merge(@update_defaults, Map.take(data, Map.keys(@update_defaults)))

    %{
      requestType: "formsubmit",
      launchType: "popup",
      id: id,
      list_type: data["list_type"],
      s_name: data["s_name"],
      lists: Jason.encode!(values),
      lists_vendor: data["lists_vendor"],
      d_name: data["d_name"],
      source_type: data["source_type"],
      source_id: data["source_id"],
      agelimit_day: data["agelimit_day"],
      agelimit_hour: data["agelimit_hour"],
      agelimit_minute: data["agelimit_minute"],
      agelimit_second: data["agelimit_second"]
    }
  end

  defp session_fields(%Session{} = session, extra) do
    Map.merge(extra, %{CSRFToken: session.csrf_token, LOGGEDINUSER: session.username})
  end
end
