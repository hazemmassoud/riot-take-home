defmodule Riot.Config do
  @moduledoc """
  Single place where application configuration is read.

  The core modules (`Riot.Encryption`, `Riot.Signing`) never read config
  themselves; their callers pass these values in explicitly.
  """

  @spec cipher() :: module()
  def cipher, do: Application.fetch_env!(:riot, :cipher)

  @doc "Key for the cipher; `nil` for keyless ciphers such as Base64."
  @spec cipher_key() :: term()
  def cipher_key, do: Application.get_env(:riot, :cipher_key)

  @spec signer() :: module()
  def signer, do: Application.fetch_env!(:riot, :signer)

  @spec signing_key() :: term()
  def signing_key, do: Application.fetch_env!(:riot, :signing_key)

  @doc """
  Key used to verify signatures. Defaults to the signing key, which is
  correct for symmetric signers such as HMAC; asymmetric signers set it to
  the public key.
  """
  @spec verification_key() :: term()
  def verification_key, do: Application.get_env(:riot, :verification_key) || signing_key()

  @spec max_body_bytes() :: pos_integer()
  def max_body_bytes, do: Application.fetch_env!(:riot, :max_body_bytes)

  @spec port() :: :inet.port_number()
  def port, do: Application.get_env(:riot, :port, 4000)

  @spec server?() :: boolean()
  def server?, do: Application.get_env(:riot, :server, true)
end
