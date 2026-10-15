defmodule RiotWeb.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import ExUnit.CaptureLog

  alias RiotWeb.Router

  @person ~s({"name":"John Doe","age":30,"contact":{"email":"john@example.com","phone":"123-456-7890"}})

  # The spec's /encrypt example, encrypted: Base64 of each value's JSON.
  @encrypted_person %{
    "name" => "IkpvaG4gRG9lIg==",
    "age" => "MzA=",
    "contact" => "eyJlbWFpbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJwaG9uZSI6IjEyMy00NTYtNzg5MCJ9"
  }

  # HMAC-SHA256 of {"message":"Hello World","timestamp":1616161616} with the
  # test key, computed independently with `openssl dgst -sha256 -hmac`.
  @hello_signature "aa3af72589cc999fcf2cd1c7d32a878a857a62b2493c95c28672096c591b062b"

  defp request(method, path, body) do
    method
    |> conn(path, body)
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Router.call(Router.init([]))
  end

  defp post_json(path, body), do: request(:post, path, body)

  defp json_body(conn), do: JSON.decode!(conn.resp_body)

  defp verify_body(signature, data),
    do: JSON.encode!(%{"signature" => signature, "data" => data})

  describe "POST /encrypt and /decrypt" do
    test "encrypts the spec example to Base64 of each top-level value" do
      conn = post_json("/encrypt", @person)

      assert conn.status == 200
      assert json_body(conn) == @encrypted_person
    end

    test "decrypts the spec example back to the original" do
      conn = post_json("/decrypt", JSON.encode!(@encrypted_person))

      assert conn.status == 200
      assert json_body(conn) == JSON.decode!(@person)
    end

    test "decrypts the spec example with an unencrypted birth_date left unchanged" do
      input = @encrypted_person |> Map.put("birth_date", "1998-11-19") |> JSON.encode!()

      assert "/decrypt" |> post_json(input) |> json_body() ==
               @person |> JSON.decode!() |> Map.put("birth_date", "1998-11-19")
    end

    test "round-trips through both endpoints" do
      encrypted = post_json("/encrypt", @person)
      assert "/decrypt" |> post_json(encrypted.resp_body) |> json_body() == JSON.decode!(@person)
    end

    test "only touches depth-1 values" do
      input = ~s({"nested":{"inner":"MTIz"}})
      assert "/decrypt" |> post_json(input) |> json_body() == %{"nested" => %{"inner" => "MTIz"}}
    end

    test "handles an empty object" do
      assert "/encrypt" |> post_json("{}") |> json_body() == %{}
      assert "/decrypt" |> post_json("{}") |> json_body() == %{}
    end

    test "rejects bodies that are not JSON objects" do
      assert post_json("/encrypt", "[1,2]").status == 400
      assert post_json("/decrypt", "\"hello\"").status == 400
    end
  end

  describe "POST /sign and /verify" do
    test "signs the spec example with a stable HMAC-SHA256 signature" do
      conn = post_json("/sign", ~s({"message":"Hello World","timestamp":1616161616}))

      assert conn.status == 200
      assert json_body(conn) == %{"signature" => @hello_signature}
    end

    test "signature does not depend on property order" do
      conn = post_json("/sign", ~s({"timestamp":1616161616,"message":"Hello World"}))
      assert json_body(conn) == %{"signature" => @hello_signature}
    end

    test "returns 204 for a valid signature, in either property order" do
      for data <- [
            ~s({"message":"Hello World","timestamp":1616161616}),
            ~s({"timestamp":1616161616,"message":"Hello World"})
          ] do
        conn = post_json("/verify", ~s({"signature":"#{@hello_signature}","data":#{data}}))

        assert conn.status == 204
        assert conn.resp_body == ""
      end
    end

    test "returns 400 for tampered data" do
      data = %{"timestamp" => 1_616_161_616, "message" => "Goodbye World"}
      assert post_json("/verify", verify_body(@hello_signature, data)).status == 400
    end

    test "returns 400 for a tampered signature" do
      data = %{"timestamp" => 1_616_161_616, "message" => "Hello World"}
      tampered = "0" <> binary_part(@hello_signature, 1, 63)

      assert post_json("/verify", verify_body(tampered, data)).status == 400
    end

    test "signs and verifies any JSON value, not just objects" do
      for data <- [[1, 2], "s", 42, nil, true, %{}] do
        %{"signature" => signature} = "/sign" |> post_json(JSON.encode!(data)) |> json_body()
        assert post_json("/verify", verify_body(signature, data)).status == 204
      end
    end

    test "treats a signature key inside data as ordinary data" do
      data = %{"signature" => "inner", "x" => 1}
      %{"signature" => signature} = "/sign" |> post_json(JSON.encode!(data)) |> json_body()

      assert post_json("/verify", verify_body(signature, data)).status == 204
    end

    test "returns 400 for a malformed verify request" do
      for body <- [
            ~s({"data":{}}),
            ~s({"signature":1,"data":{}}),
            ~s({"signature":"x"}),
            "[]",
            "null"
          ] do
        conn = post_json("/verify", body)

        assert conn.status == 400
        assert json_body(conn)["error"] =~ "signature"
      end
    end
  end

  describe "request handling" do
    test "returns 400 for invalid JSON" do
      for body <- ["{not json", "", ~s({"a":1} trailing)] do
        conn = post_json("/encrypt", body)

        assert conn.status == 400
        assert json_body(conn) == %{"error" => "request body is not valid JSON"}
      end
    end

    test "returns 400 for objects with duplicate keys, at any depth" do
      for body <- [~s({"a":1,"a":2}), ~s({"data":{"x":1,"x":2},"signature":"s"})] do
        conn = post_json("/verify", body)

        assert conn.status == 400
        assert json_body(conn) == %{"error" => "request body has an object with a duplicate key"}
      end
    end

    test "returns 413 for bodies over the size limit" do
      big = JSON.encode!(%{"a" => String.duplicate("x", 1_000_001)})
      conn = post_json("/sign", big)

      assert conn.status == 413
      assert json_body(conn) == %{"error" => "request body is too large"}
    end

    test "works without a content-type header" do
      conn = :post |> conn("/sign", "{}") |> Router.call(Router.init([]))
      assert conn.status == 200
    end

    test "returns 405 with an allow header for other methods on known routes" do
      conn = request(:get, "/encrypt", "")

      assert conn.status == 405
      assert Plug.Conn.get_resp_header(conn, "allow") == ["POST"]
    end

    test "returns 404 for unknown routes" do
      assert post_json("/nope", "{}").status == 404
    end

    test "never logs request payloads" do
      secret = "s3cr3t-payload-value"

      log =
        capture_log(fn ->
          for path <- ~w(/encrypt /decrypt /sign /verify) do
            post_json(path, JSON.encode!(%{"secret" => secret}))
          end
        end)

      refute log =~ secret
    end
  end
end
