defmodule Riot.Crypto.Signer do
  @moduledoc """
  Port for keyed signatures over raw binaries.

  Signing and verification take separate keys so asymmetric algorithms
  (sign with a private key, verify with a public key) fit the same contract.
  Symmetric algorithms such as HMAC are given the same secret for both.
  Keys are opaque to callers.

  Implementations must compare signatures in constant time in `verify/3`.
  """

  @type key :: term()

  @callback sign(data :: binary(), signing_key :: key()) :: String.t()
  @callback verify(data :: binary(), signature :: String.t(), verification_key :: key()) ::
              boolean()
end
