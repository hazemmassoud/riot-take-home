# Riot take-home: conventions

- Toolchain is pinned in `mise.toml`; run commands via mise (`mise exec -- mix ...`).
- Layering: `RiotWeb.*` (HTTP adapter) → `Riot.Encryption` / `Riot.Signing` / `Riot.CanonicalJSON` (pure core) → `Riot.Crypto.Cipher` / `Riot.Crypto.Signer` behaviours → implementations.
  - The core never reads config or touches `Plug.Conn`; callers pass the algorithm module and key.
  - Only `Riot.Config` reads application env. Only `RiotWeb.Response` maps error atoms to HTTP status.
- Use the built-in `JSON` module (no Jason).
- Expected failures are `{:error, atom}` / `:error`, not exceptions.
- Never log request payloads.
- Before committing: `mix format && mix credo --strict && mix test && mix dialyzer`.
- Keep the README's "Design decisions" section in sync with behaviour changes.
