defmodule RiotWeb.Response do
  @moduledoc """
  Turns handler results into HTTP responses.

  This is the only place where domain-level error reasons are mapped to
  HTTP status codes.
  """

  import Plug.Conn

  @type result :: {:ok, Plug.Conn.status(), term()} | {:ok, :no_content} | {:error, atom()}

  @spec render(Plug.Conn.t(), result()) :: Plug.Conn.t()
  def render(conn, {:ok, :no_content}), do: send_resp(conn, 204, "")
  def render(conn, {:ok, status, body}), do: json(conn, status, body)

  def render(conn, {:error, :method_not_allowed}) do
    conn
    |> put_resp_header("allow", "POST")
    |> json(405, %{"error" => message_for(:method_not_allowed)})
  end

  def render(conn, {:error, reason}) do
    json(conn, status_for(reason), %{"error" => message_for(reason)})
  end

  @spec json(Plug.Conn.t(), Plug.Conn.status(), term()) :: Plug.Conn.t()
  def json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, JSON.encode!(body))
  end

  @spec file(Plug.Conn.t(), String.t(), Path.t()) :: Plug.Conn.t()
  def file(conn, content_type, path) do
    conn
    |> put_resp_content_type(content_type)
    |> send_file(200, path)
  end

  @spec redirect(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def redirect(conn, location) do
    conn
    |> put_resp_header("location", location)
    |> send_resp(302, "")
  end

  defp status_for(:payload_too_large), do: 413
  defp status_for(:not_found), do: 404
  defp status_for(:encryption_failed), do: 500
  defp status_for(_bad_request), do: 400

  defp message_for(:payload_too_large), do: "request body is too large"
  defp message_for(:unreadable_body), do: "request body could not be read"
  defp message_for(:invalid_json), do: "request body is not valid JSON"
  defp message_for(:duplicate_key), do: "request body has an object with a duplicate key"
  defp message_for(:not_an_object), do: "request body must be a JSON object"

  defp message_for(:invalid_verify_request),
    do: ~s(request body must be an object with a string "signature" and a "data" property)

  defp message_for(:invalid_signature), do: "signature is invalid"
  defp message_for(:invalid_ciphertext), do: "a value looks encrypted but could not be decrypted"
  defp message_for(:encryption_failed), do: "encryption failed"
  defp message_for(:method_not_allowed), do: "method not allowed"
  defp message_for(:not_found), do: "not found"
end
