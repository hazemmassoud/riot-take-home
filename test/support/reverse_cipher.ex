defmodule Riot.Test.ReverseCipher do
  @moduledoc """
  Test-only cipher that reverses bytes, used to prove ciphers are swappable.

  Ciphertext is `"rev:" <> reversed`; `"rev!"` marks ciphertext that is
  recognizably ours but corrupt, to exercise the `{:error, _}` path.
  """

  @behaviour Riot.Crypto.Cipher

  @impl true
  def encrypt(plaintext, _key), do: {:ok, "rev:" <> reverse(plaintext)}

  @impl true
  def decrypt("rev:" <> ciphertext, _key), do: {:ok, reverse(ciphertext)}
  def decrypt("rev!" <> _corrupt, _key), do: {:error, :corrupt}
  def decrypt(_other, _key), do: :not_ciphertext

  defp reverse(binary),
    do: binary |> :binary.bin_to_list() |> Enum.reverse() |> :binary.list_to_bin()
end
