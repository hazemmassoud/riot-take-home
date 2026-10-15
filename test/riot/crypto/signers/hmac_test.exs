defmodule Riot.Crypto.Signers.HMACTest do
  use ExUnit.Case, async: true

  alias Riot.Crypto.Signers.HMAC

  test "produces the RFC 4231 HMAC-SHA256 test vector" do
    # RFC 4231, test case 2
    assert HMAC.sign("what do ya want for nothing?", "Jefe") ==
             "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
  end

  test "verifies its own signatures" do
    assert HMAC.verify("data", HMAC.sign("data", "key"), "key")
  end

  test "rejects a signature made with another key or for other data" do
    signature = HMAC.sign("data", "key")

    refute HMAC.verify("data", signature, "other-key")
    refute HMAC.verify("other-data", signature, "key")
    refute HMAC.verify("data", "not-a-signature", "key")
  end
end
