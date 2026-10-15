defmodule Riot.Encryption do
  @moduledoc """
  Encrypts and decrypts the top-level properties of a JSON object.

  Each value is serialized to JSON before encryption, so its type survives
  the round trip (`30` comes back as a number, not `"30"`).

  On decryption, a value is replaced only if it is a string that the cipher
  accepts as ciphertext *and* whose plaintext is valid JSON. Values the
  cipher reports as `:not_ciphertext` are returned unchanged; values it
  reports as `{:error, reason}` fail the whole request. With Base64 this has
  a known false positive: a plain string that happens to be valid Base64 of
  valid JSON (e.g. `"MTIz"`, which decodes to `123`) will be decrypted. See
  the README for the trade-off.
  """

  alias Riot.Crypto.Cipher

  @type object :: %{optional(String.t()) => term()}

  # Cipher-specific error reasons are normalized to these two, so callers
  # handle a closed set regardless of which cipher is configured.
  @spec encrypt(object(), module(), Cipher.key()) ::
          {:ok, %{optional(String.t()) => String.t()}} | {:error, :encryption_failed}
  def encrypt(object, cipher, key) when is_map(object) do
    map_values(object, &encrypt_value(&1, cipher, key))
  end

  @spec decrypt(object(), module(), Cipher.key()) ::
          {:ok, object()} | {:error, :invalid_ciphertext}
  def decrypt(object, cipher, key) when is_map(object) do
    map_values(object, &decrypt_value(&1, cipher, key))
  end

  defp encrypt_value(value, cipher, key) do
    case value |> JSON.encode!() |> cipher.encrypt(key) do
      {:ok, ciphertext} -> {:ok, ciphertext}
      {:error, _reason} -> {:error, :encryption_failed}
    end
  end

  defp decrypt_value(value, cipher, key) when is_binary(value) do
    case cipher.decrypt(value, key) do
      {:ok, plaintext} -> decode_plaintext(plaintext, value)
      :not_ciphertext -> {:ok, value}
      {:error, _reason} -> {:error, :invalid_ciphertext}
    end
  end

  defp decrypt_value(value, _cipher, _key), do: {:ok, value}

  # Plaintext that is not JSON means the string only happened to be valid
  # ciphertext syntax (e.g. any Base64), so it was never encrypted by us.
  defp decode_plaintext(plaintext, original) do
    case JSON.decode(plaintext) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:ok, original}
    end
  end

  # Applies `fun` to every value, stopping at the first `{:error, reason}`.
  defp map_values(object, fun) do
    Enum.reduce_while(object, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case fun.(value) do
        {:ok, mapped} -> {:cont, {:ok, Map.put(acc, key, mapped)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
