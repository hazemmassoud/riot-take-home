defmodule Riot.Crypto.Ciphers.Base64 do
  @moduledoc """
  Base64 "encryption", as required by the challenge.

  This is an encoding, not encryption: it gives no confidentiality and
  ignores the key. Decoding is strict (standard alphabet, padding required),
  so strings such as `"1998-11-19"` are rejected as non-ciphertext.
  """

  @behaviour Riot.Crypto.Cipher

  @impl true
  def encrypt(plaintext, _key) when is_binary(plaintext), do: {:ok, Base.encode64(plaintext)}

  @impl true
  def decrypt(ciphertext, _key) when is_binary(ciphertext) do
    case Base.decode64(ciphertext) do
      {:ok, plaintext} -> {:ok, plaintext}
      :error -> :not_ciphertext
    end
  end
end
