defmodule Riot.SigningTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Riot.JSONGenerators

  alias Riot.Crypto.Signers.HMAC
  alias Riot.Signing
  alias Riot.Test.Ed25519Signer

  @key "test-key"

  test "property order does not change the signature" do
    a = JSON.decode!(~s({"message":"Hello World","timestamp":1616161616}))
    b = JSON.decode!(~s({"timestamp":1616161616,"message":"Hello World"}))

    assert Signing.sign(a, HMAC, @key) == Signing.sign(b, HMAC, @key)
  end

  test "rejects non-string signatures" do
    refute Signing.verify(%{}, 123, HMAC, @key)
    refute Signing.verify(%{}, nil, HMAC, @key)
  end

  test "signatures are case-sensitive lowercase hex" do
    signature = Signing.sign(%{"a" => 1}, HMAC, @key)

    assert signature =~ ~r/\A[0-9a-f]{64}\z/
    refute Signing.verify(%{"a" => 1}, String.upcase(signature), HMAC, @key)
  end

  test "an asymmetric signer signs with the private key and verifies with the public key" do
    {public_key, private_key} = Ed25519Signer.generate_keys()
    {other_public_key, _other_private_key} = Ed25519Signer.generate_keys()
    value = %{"message" => "Hello World", "timestamp" => 1_616_161_616}

    signature = Signing.sign(value, Ed25519Signer, private_key)

    assert Signing.verify(value, signature, Ed25519Signer, public_key)
    refute Signing.verify(value, signature, Ed25519Signer, other_public_key)

    refute Signing.verify(
             %{value | "message" => "Goodbye World"},
             signature,
             Ed25519Signer,
             public_key
           )
  end

  property "a signed value verifies even after its keys are reordered" do
    check all(value <- json_value()) do
      signature = Signing.sign(value, HMAC, @key)
      reordered = value |> shuffled_json() |> JSON.decode!()

      assert Signing.verify(reordered, signature, HMAC, @key)
    end
  end

  property "adding a property invalidates the signature" do
    check all(object <- json_object(), extra <- json_value()) do
      signature = Signing.sign(object, HMAC, @key)
      tampered = Map.put(object, "tampered-#{System.unique_integer()}", extra)

      refute Signing.verify(tampered, signature, HMAC, @key)
    end
  end

  property "changing an existing value invalidates the signature" do
    check all(
            object <- json_object(),
            key <- string(:printable, max_length: 10),
            original <- json_value(),
            replacement <- json_value(),
            original != replacement
          ) do
      signed = Map.put(object, key, original)
      signature = Signing.sign(signed, HMAC, @key)

      refute Signing.verify(Map.put(signed, key, replacement), signature, HMAC, @key)
    end
  end

  property "reordering an array invalidates the signature" do
    check all(list <- uniq_list_of(integer(), min_length: 2, max_length: 10)) do
      signature = Signing.sign(list, HMAC, @key)
      refute Signing.verify(Enum.reverse(list), signature, HMAC, @key)
    end
  end
end
