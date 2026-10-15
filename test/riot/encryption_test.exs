defmodule Riot.EncryptionTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Riot.JSONGenerators

  alias Riot.Crypto.Ciphers.Base64
  alias Riot.Encryption
  alias Riot.Test.ReverseCipher

  @person %{
    "name" => "John Doe",
    "age" => 30,
    "contact" => %{"email" => "john@example.com", "phone" => "123-456-7890"}
  }

  test "encrypts every top-level value as Base64 of its JSON" do
    {:ok, encrypted} = Encryption.encrypt(@person, Base64, nil)

    assert encrypted["name"] == Base.encode64(~s("John Doe"))
    assert encrypted["age"] == Base.encode64("30")
    assert Base.decode64!(encrypted["contact"]) |> JSON.decode!() == @person["contact"]
  end

  test "leaves values that were not encrypted unchanged" do
    {:ok, encrypted} = Encryption.encrypt(@person, Base64, nil)
    payload = Map.put(encrypted, "birth_date", "1998-11-19")

    assert Encryption.decrypt(payload, Base64, nil) ==
             {:ok, Map.put(@person, "birth_date", "1998-11-19")}
  end

  test "leaves non-string values unchanged" do
    payload = %{"n" => 1, "list" => [1, 2], "obj" => %{"a" => 1}, "nil" => nil}
    assert Encryption.decrypt(payload, Base64, nil) == {:ok, payload}
  end

  test "leaves valid Base64 that does not decode to JSON unchanged" do
    # "Zm9v" is Base64 for "foo", which is not JSON.
    assert Encryption.decrypt(%{"a" => "Zm9v"}, Base64, nil) == {:ok, %{"a" => "Zm9v"}}
  end

  test "decrypts plain strings that are valid Base64 of JSON (documented false positive)" do
    # "MTIz" is Base64 for "123"; Base64 has no way to tell it was never encrypted.
    assert Encryption.decrypt(%{"a" => "MTIz"}, Base64, nil) == {:ok, %{"a" => 123}}
  end

  test "fails instead of passing through ciphertext the cipher recognizes but cannot decrypt" do
    payload = %{"ok" => "plain", "bad" => "rev!corrupt"}
    assert Encryption.decrypt(payload, ReverseCipher, nil) == {:error, :invalid_ciphertext}
  end

  property "decrypt never fails on arbitrary strings with Base64" do
    check all(value <- one_of([string(:alphanumeric), map(binary(), &Base.encode64/1)])) do
      assert {:ok, %{"v" => _decrypted}} = Encryption.decrypt(%{"v" => value}, Base64, nil)
    end
  end

  for cipher <- [Base64, ReverseCipher] do
    property "decrypt(encrypt(x)) == x with #{inspect(cipher)}" do
      check all(object <- json_object()) do
        {:ok, encrypted} = Encryption.encrypt(object, unquote(cipher), nil)
        assert Encryption.decrypt(encrypted, unquote(cipher), nil) == {:ok, object}
      end
    end
  end
end
