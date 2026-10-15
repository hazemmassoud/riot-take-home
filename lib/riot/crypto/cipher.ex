defmodule Riot.Crypto.Cipher do
  @moduledoc """
  Port for reversible encryption of raw binaries.

  Implementations know nothing about JSON. The key is opaque to callers and
  may be `nil` for keyless ciphers such as Base64.

  Ciphertext must be a printable string, because it is embedded in a JSON
  response; implementations choose the encoding (e.g. Base64 of
  nonce ‖ ciphertext ‖ tag for an AEAD cipher).

  `decrypt/2` distinguishes two failures:

    * `:not_ciphertext` - the input is not something this cipher produced,
      which is how `Riot.Encryption` detects values that were never encrypted.
    * `{:error, reason}` - the input looks like this cipher's ciphertext but
      cannot be decrypted (e.g. a failed authentication tag), which must not
      be silently passed through.
  """

  @type key :: term()

  @callback encrypt(plaintext :: binary(), key()) :: {:ok, String.t()} | {:error, atom()}
  @callback decrypt(ciphertext :: String.t(), key()) ::
              {:ok, binary()} | :not_ciphertext | {:error, atom()}
end
