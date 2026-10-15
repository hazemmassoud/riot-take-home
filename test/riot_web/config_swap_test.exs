defmodule RiotWeb.ConfigSwapTest do
  # Not async: these tests change application config.
  use ExUnit.Case, async: false
  import Plug.Test

  alias Riot.Test.{Ed25519Signer, ReverseCipher}
  alias RiotWeb.Router

  defp post_json(path, body), do: :post |> conn(path, body) |> Router.call(Router.init([]))

  defp put_config(settings) do
    for {key, value} <- settings do
      previous = Application.fetch_env(:riot, key)
      Application.put_env(:riot, key, value)
      on_exit(fn -> restore_config(key, previous) end)
    end
  end

  defp restore_config(key, {:ok, value}), do: Application.put_env(:riot, key, value)
  defp restore_config(key, :error), do: Application.delete_env(:riot, key)

  test "swapping the cipher in config changes /encrypt and /decrypt with no code changes" do
    put_config(cipher: ReverseCipher)

    encrypted = post_json("/encrypt", ~s({"name":"John Doe"}))
    assert JSON.decode!(encrypted.resp_body) == %{"name" => ~s(rev:"eoD nhoJ")}

    decrypted = post_json("/decrypt", encrypted.resp_body)
    assert JSON.decode!(decrypted.resp_body) == %{"name" => "John Doe"}

    assert post_json("/decrypt", ~s({"name":"rev!corrupt"})).status == 400
  end

  test "swapping to an asymmetric signer only needs config" do
    {public_key, private_key} = Ed25519Signer.generate_keys()
    put_config(signer: Ed25519Signer, signing_key: private_key, verification_key: public_key)

    data = ~s({"message":"Hello World","timestamp":1616161616})

    %{"signature" => signature} =
      "/sign" |> post_json(data) |> Map.get(:resp_body) |> JSON.decode!()

    assert post_json("/verify", ~s({"signature":"#{signature}","data":#{data}})).status == 204
  end
end
