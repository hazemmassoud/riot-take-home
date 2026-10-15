defmodule Riot.CanonicalJSON do
  @moduledoc """
  Deterministic JSON serialization, so that equal values produce equal bytes.

  Object keys are sorted recursively and no whitespace is emitted; array
  order is preserved because it is part of the value. This is a pragmatic
  subset of RFC 8785 (JCS): keys are sorted by UTF-8 bytes rather than UTF-16
  code units, and numbers use Elixir's own formatting, so `1` and `1.0` are
  treated as different values. `-0.0` is normalized to `0.0`, since JSON
  parsers disagree on whether they are distinct.
  """

  @typedoc "A decoded JSON value."
  @type json ::
          nil
          | boolean()
          | number()
          | String.t()
          | [json()]
          | %{optional(String.t()) => json()}

  @spec encode(json()) :: String.t()
  def encode(value), do: value |> encode_iodata() |> IO.iodata_to_binary()

  defp encode_iodata(map) when is_map(map) do
    members =
      map
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map(fn {key, value} -> [JSON.encode!(key), ?:, encode_iodata(value)] end)

    [?{, Enum.intersperse(members, ?,), ?}]
  end

  defp encode_iodata(list) when is_list(list) do
    [?[, list |> Enum.map(&encode_iodata/1) |> Enum.intersperse(?,), ?]]
  end

  defp encode_iodata(float) when is_float(float) and float == 0.0, do: "0.0"
  defp encode_iodata(scalar), do: JSON.encode!(scalar)
end
