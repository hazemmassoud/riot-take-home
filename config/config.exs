import Config

# Swap algorithms here: any module implementing the matching behaviour works.
# Keyed ciphers also need `cipher_key:`; asymmetric signers set `signing_key:`
# to the private key and `verification_key:` to the public key.
config :riot,
  cipher: Riot.Crypto.Ciphers.Base64,
  signer: Riot.Crypto.Signers.HMAC,
  max_body_bytes: 1_000_000

import_config "#{config_env()}.exs"
