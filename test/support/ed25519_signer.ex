defmodule Riot.Test.Ed25519Signer do
  @moduledoc """
  Test-only asymmetric signer, used to prove the signer port fits algorithms
  that sign with a private key and verify with a public key.
  """

  @behaviour Riot.Crypto.Signer

  @doc "Returns `{public_key, private_key}`."
  def generate_keys, do: :crypto.generate_key(:eddsa, :ed25519)

  @impl true
  def sign(data, private_key) do
    :eddsa |> :crypto.sign(:none, data, [private_key, :ed25519]) |> Base.encode16(case: :lower)
  end

  @impl true
  def verify(data, signature, public_key) do
    case Base.decode16(signature, case: :lower) do
      {:ok, raw} -> :crypto.verify(:eddsa, :none, data, raw, [public_key, :ed25519])
      :error -> false
    end
  end
end
