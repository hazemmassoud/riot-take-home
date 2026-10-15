defmodule Riot.Crypto.Signers.HMAC do
  @moduledoc """
  HMAC-SHA256 signer. Signatures are lowercase hex strings.

  HMAC is symmetric: the signing and verification keys are the same secret.
  """

  @behaviour Riot.Crypto.Signer

  @impl true
  def sign(data, key) when is_binary(data) and is_binary(key) do
    :hmac
    |> :crypto.mac(:sha256, key, data)
    |> Base.encode16(case: :lower)
  end

  @impl true
  def verify(data, signature, key) when is_binary(signature) do
    Plug.Crypto.secure_compare(sign(data, key), signature)
  end
end
