defmodule RiotWeb.JSONBody do
  @moduledoc """
  Reads and decodes a JSON request body.

  Used instead of `Plug.Parsers` because that parser wraps non-object bodies
  as `%{"_json" => value}`, which is indistinguishable from a real object with
  a `"_json"` key. The `Content-Type` header is deliberately not enforced so
  plain `curl -d` requests work.

  Objects with duplicate keys are rejected. JSON parsers disagree on which
  duplicate wins (Elixir keeps the first, most others keep the last), so a
  signature over such a payload could cover a different value than the one
  another system reads.
  """

  alias Plug.Conn

  @type error :: :payload_too_large | :unreadable_body | :invalid_json | :duplicate_key

  @spec read(Conn.t(), pos_integer()) :: {:ok, term(), Conn.t()} | {:error, error(), Conn.t()}
  def read(conn, max_bytes) do
    case Conn.read_body(conn, length: max_bytes) do
      {:ok, body, conn} ->
        case decode(body) do
          {:ok, value} -> {:ok, value, conn}
          {:error, reason} -> {:error, reason, conn}
        end

      {:more, _partial, conn} ->
        {:error, :payload_too_large, conn}

      {:error, _reason} ->
        {:error, :unreadable_body, conn}
    end
  end

  @spec decode(binary()) :: {:ok, term()} | {:error, :invalid_json | :duplicate_key}
  def decode(body) do
    case JSON.decode(body, :ok, object_finish: &finish_object/2) do
      {value, :ok, ""} -> {:ok, value}
      {:error, _reason} -> {:error, :invalid_json}
      {_value, _acc, _trailing_bytes} -> {:error, :invalid_json}
    end
  catch
    :duplicate_key -> {:error, :duplicate_key}
  end

  # The decoder collects members as a list; if building the map drops any,
  # a key appeared twice. The throw never escapes `decode/1`.
  defp finish_object(members, acc) do
    object = Map.new(members)

    if map_size(object) == length(members),
      do: {object, acc},
      else: throw(:duplicate_key)
  end
end
