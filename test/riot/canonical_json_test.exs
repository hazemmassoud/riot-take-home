defmodule Riot.CanonicalJSONTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Riot.JSONGenerators

  alias Riot.CanonicalJSON

  test "sorts keys recursively and keeps array order" do
    value = %{"b" => [3, 1, %{"z" => 1, "a" => 2}], "a" => %{"y" => true, "x" => nil}}

    assert CanonicalJSON.encode(value) ==
             ~s({"a":{"x":null,"y":true},"b":[3,1,{"a":2,"z":1}]})
  end

  test "sorts unicode keys by UTF-8 bytes" do
    assert CanonicalJSON.encode(%{"é" => 1, "z" => 2, "A" => 3}) == ~s({"A":3,"z":2,"é":1})
  end

  test "normalizes negative zero and keeps integers distinct from floats" do
    assert CanonicalJSON.encode(-0.0) == CanonicalJSON.encode(0.0)
    refute CanonicalJSON.encode(1) == CanonicalJSON.encode(1.0)
  end

  property "the same value always encodes to the same bytes regardless of input key order" do
    check all(value <- json_value()) do
      reparsed = value |> shuffled_json() |> JSON.decode!()
      assert CanonicalJSON.encode(reparsed) == CanonicalJSON.encode(value)
    end
  end

  property "output is valid JSON that decodes back to the same value" do
    check all(value <- json_value()) do
      assert value |> CanonicalJSON.encode() |> JSON.decode!() == value
    end
  end
end
