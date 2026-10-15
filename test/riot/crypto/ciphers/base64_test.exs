defmodule Riot.Crypto.Ciphers.Base64Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Riot.Crypto.Ciphers.Base64

  property "decrypt reverses encrypt" do
    check all(plaintext <- binary()) do
      {:ok, ciphertext} = Base64.encrypt(plaintext, nil)
      assert Base64.decrypt(ciphertext, nil) == {:ok, plaintext}
    end
  end

  test "rejects strings outside the Base64 alphabet as non-ciphertext" do
    assert Base64.decrypt("1998-11-19", nil) == :not_ciphertext
    assert Base64.decrypt("John Doe", nil) == :not_ciphertext
  end
end
