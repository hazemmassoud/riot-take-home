defmodule RiotWeb.DocsTest do
  # Not async: the spec's /verify examples are signed with the dev key, so the
  # signing key is switched to it for the duration of these tests.
  use ExUnit.Case, async: false
  import Plug.Test

  alias RiotWeb.{JSONBody, Router}

  @dev_key "dev-only-signing-key-do-not-use-in-prod"

  setup do
    previous = Application.fetch_env!(:riot, :signing_key)
    Application.put_env(:riot, :signing_key, @dev_key)
    on_exit(fn -> Application.put_env(:riot, :signing_key, previous) end)
  end

  defp request(method, path, body \\ ""),
    do: method |> conn(path, body) |> Router.call(Router.init([]))

  defp spec do
    {:ok, spec} = JSONBody.decode(request(:get, "/openapi.json").resp_body)
    spec
  end

  # Resolves `{"$ref": "#/components/..."}` against the spec.
  defp resolve(spec, %{"$ref" => "#/" <> path}), do: get_in(spec, String.split(path, "/"))
  defp resolve(_spec, value), do: value

  test "GET / redirects to the docs" do
    conn = request(:get, "/")

    assert conn.status == 302
    assert Plug.Conn.get_resp_header(conn, "location") == ["/docs"]
  end

  test "GET /docs serves Swagger UI pointed at the spec" do
    conn = request(:get, "/docs")

    assert conn.status == 200
    assert ["text/html" <> _charset] = Plug.Conn.get_resp_header(conn, "content-type")
    assert conn.resp_body =~ ~s(url: "/openapi.json")
  end

  test "the spec documents exactly the four POST endpoints" do
    paths = spec()["paths"]

    assert paths |> Map.keys() |> Enum.sort() == ~w(/decrypt /encrypt /sign /verify)
    assert Enum.all?(paths, fn {_path, operations} -> Map.keys(operations) == ["post"] end)
  end

  test "every request example returns its documented status" do
    spec = spec()

    for {path, %{"post" => operation}} <- spec["paths"],
        {name, example} <- operation["requestBody"]["content"]["application/json"]["examples"] do
      %{"summary" => summary, "value" => value} = resolve(spec, example)
      conn = request(:post, path, JSON.encode!(value))

      expected =
        if summary =~ "(400)",
          do: 400,
          else: operation["responses"] |> Map.keys() |> Enum.min() |> String.to_integer()

      assert conn.status == expected, "#{path} example #{name}: got #{conn.status}"
      assert Map.has_key?(operation["responses"], Integer.to_string(conn.status))
    end
  end

  test "documented 200 response examples match the API's output" do
    spec = spec()
    examples = spec["components"]["examples"]

    for {path, input, output} <- [
          {"/encrypt", "Person", "EncryptedPerson"},
          {"/decrypt", "EncryptedPerson", "Person"}
        ] do
      body = request(:post, path, JSON.encode!(examples[input]["value"])).resp_body
      assert JSON.decode!(body) == examples[output]["value"]
    end

    sign_input = spec["paths"]["/sign"]["post"]["requestBody"]["content"]["application/json"]
    body = request(:post, "/sign", JSON.encode!(sign_input["examples"]["message"]["value"]))
    assert JSON.decode!(body.resp_body) == examples["DevSignature"]["value"]
  end
end
