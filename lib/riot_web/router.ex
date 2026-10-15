defmodule RiotWeb.Router do
  @moduledoc """
  HTTP adapter. Parses requests, calls the core with configured algorithms,
  and renders the result. Holds no business logic.
  """

  use Plug.Router
  use Plug.ErrorHandler

  require Logger

  alias Riot.{Config, Encryption, Signing}
  alias RiotWeb.{JSONBody, Response}

  @endpoints ~w(encrypt decrypt sign verify)

  plug(:match)
  plug(:dispatch)

  post "/encrypt" do
    handle(conn, fn payload ->
      with {:ok, object} <- require_object(payload),
           {:ok, encrypted} <- Encryption.encrypt(object, Config.cipher(), Config.cipher_key()) do
        {:ok, 200, encrypted}
      end
    end)
  end

  post "/decrypt" do
    handle(conn, fn payload ->
      with {:ok, object} <- require_object(payload),
           {:ok, decrypted} <- Encryption.decrypt(object, Config.cipher(), Config.cipher_key()) do
        {:ok, 200, decrypted}
      end
    end)
  end

  post "/sign" do
    handle(conn, fn payload ->
      {:ok, 200, %{"signature" => Signing.sign(payload, Config.signer(), Config.signing_key())}}
    end)
  end

  post "/verify" do
    handle(conn, fn
      %{"signature" => signature, "data" => data} when is_binary(signature) ->
        if Signing.verify(data, signature, Config.signer(), Config.verification_key()),
          do: {:ok, :no_content},
          else: {:error, :invalid_signature}

      _malformed ->
        {:error, :invalid_verify_request}
    end)
  end

  get "/" do
    Response.redirect(conn, "/docs")
  end

  # Interactive API docs: Swagger UI rendering priv/static/openapi.json.
  get "/docs" do
    Response.file(conn, "text/html", static_path("docs.html"))
  end

  get "/openapi.json" do
    Response.file(conn, "application/json", static_path("openapi.json"))
  end

  match "/:endpoint" when endpoint in @endpoints do
    Response.render(conn, {:error, :method_not_allowed})
  end

  match _ do
    Response.render(conn, {:error, :not_found})
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{kind: kind, reason: reason}) do
    # Log the failure type only: request payloads may contain sensitive data.
    Logger.error("request failed: #{kind} #{failure_type(reason)}")
    Response.json(conn, conn.status, %{"error" => "internal server error"})
  end

  defp failure_type(reason) when is_exception(reason), do: inspect(reason.__struct__)
  defp failure_type(_thrown_or_exit_reason), do: "(non-exception)"

  defp handle(conn, handler) do
    case JSONBody.read(conn, Config.max_body_bytes()) do
      {:ok, payload, conn} -> Response.render(conn, handler.(payload))
      {:error, reason, conn} -> Response.render(conn, {:error, reason})
    end
  end

  defp static_path(file), do: Application.app_dir(:riot, ["priv", "static", file])

  defp require_object(payload) when is_map(payload), do: {:ok, payload}
  defp require_object(_payload), do: {:error, :not_an_object}
end
