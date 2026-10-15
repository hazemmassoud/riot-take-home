import Config

config :riot, port: String.to_integer(System.get_env("PORT", "4000"))

signing_key = System.get_env("RIOT_SIGNING_KEY", "")

if config_env() == :prod do
  # Keys committed for dev/test are public, so they are never acceptable here.
  cond do
    signing_key == "" ->
      raise "environment variable RIOT_SIGNING_KEY is missing"

    signing_key in ["dev-only-signing-key-do-not-use-in-prod", "test-signing-key"] ->
      raise "RIOT_SIGNING_KEY is a committed dev/test key; generate a secret one"

    byte_size(signing_key) < 32 ->
      raise "RIOT_SIGNING_KEY must be at least 32 bytes"

    true ->
      :ok
  end
end

if signing_key != "" do
  config :riot, signing_key: signing_key
end
