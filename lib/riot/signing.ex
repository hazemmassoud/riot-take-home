defmodule Riot.Signing do
  @moduledoc """
  Signs and verifies JSON values by their *value*, not their text.

  The value is serialized with `Riot.CanonicalJSON` before signing, so the
  property order in the original request does not affect the signature.
  """

  alias Riot.CanonicalJSON
  alias Riot.Crypto.Signer

  @spec sign(CanonicalJSON.json(), module(), Signer.key()) :: String.t()
  def sign(value, signer, signing_key) do
    value |> CanonicalJSON.encode() |> signer.sign(signing_key)
  end

  @spec verify(CanonicalJSON.json(), term(), module(), Signer.key()) :: boolean()
  def verify(value, signature, signer, verification_key) when is_binary(signature) do
    value |> CanonicalJSON.encode() |> signer.verify(signature, verification_key)
  end

  def verify(_value, _signature, _signer, _verification_key), do: false
end
