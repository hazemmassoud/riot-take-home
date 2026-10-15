defmodule Riot.JSONGenerators do
  @moduledoc "StreamData generators for arbitrary JSON values."

  import StreamData

  def json_scalar do
    one_of([constant(nil), boolean(), integer(), float(), string(:printable, max_length: 20)])
  end

  def json_value do
    tree(json_scalar(), fn child ->
      one_of([list_of(child, max_length: 4), json_object(child)])
    end)
  end

  def json_object(value \\ json_value()) do
    map_of(string(:printable, max_length: 10), value, max_length: 5)
  end

  @doc "Encodes a JSON value with object keys in random order, recursively."
  def shuffled_json(map) when is_map(map) do
    members =
      map
      |> Enum.shuffle()
      |> Enum.map(fn {key, value} -> [JSON.encode!(key), ?:, shuffled_json(value)] end)

    IO.iodata_to_binary([?{, Enum.intersperse(members, ?,), ?}])
  end

  def shuffled_json(list) when is_list(list) do
    IO.iodata_to_binary([?[, list |> Enum.map(&shuffled_json/1) |> Enum.intersperse(?,), ?]])
  end

  def shuffled_json(scalar), do: JSON.encode!(scalar)
end
