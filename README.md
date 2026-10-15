# Riot

An HTTP API with four JSON endpoints, built for the Riot take-home challenge
([requirements.txt](requirements.txt)):

| Endpoint        | Does                                                      | Success |
| --------------- | --------------------------------------------------------- | ------- |
| `POST /encrypt` | Encrypts every top-level property (Base64)                | `200`   |
| `POST /decrypt` | Decrypts encrypted properties, leaves the rest unchanged  | `200`   |
| `POST /sign`    | Returns an HMAC-SHA256 `signature` of any JSON value      | `200`   |
| `POST /verify`  | Checks `signature` against `data`; `400` if it is invalid | `204`   |

Elixir, Plug + Bandit, and Elixir's built-in `JSON` module. Stateless: no
database and no processes beyond the HTTP server.

## Quick start

Requires Erlang/OTP 29 and Elixir 1.20, pinned in `mise.toml`.

```bash
mise install
mise exec -- mix deps.get
mise exec -- mix run --no-halt
```

The server listens on `PORT` (default `4000`). If mise is activated in your
shell, drop the `mise exec --` prefix.

## Using the API

### In the browser

Open **<http://localhost:4000/docs>** (`/` redirects there). It is Swagger UI
for the OpenAPI 3.1 spec at `/openapi.json`. Every endpoint has **Try it out**
with the challenge's examples pre-filled:

- `/encrypt` and `/decrypt`: the person example, plus one with an unencrypted
  `birth_date` that comes back unchanged.
- `/sign`: the message in both property orders, giving the same signature.
- `/verify`: a valid, a reordered (still valid) and a tampered (`400`) request.

The `/verify` examples are signed with the dev key, so they return `204` against
a local server. With any other key, call `/sign` first and paste its signature.

### With curl

```bash
curl -s localhost:4000/encrypt -d '{"name":"John Doe","age":30}'
# {"age":"MzA=","name":"IkpvaG4gRG9lIg=="}

curl -s localhost:4000/decrypt -d '{"name":"IkpvaG4gRG9lIg==","birth_date":"1998-11-19"}'
# {"birth_date":"1998-11-19","name":"John Doe"}

curl -s localhost:4000/sign -d '{"message":"Hello World","timestamp":1616161616}'
# {"signature":"1b76ca91…"}   (with the dev key)

curl -si localhost:4000/verify -d '{"signature":"1b76ca91b8696a956fbdea01c1afd053356c7ca8f26ac304b28e0e60e3bffbff","data":{"timestamp":1616161616,"message":"Hello World"}}'
# HTTP/1.1 204 No Content
```

### Errors

Errors are JSON, `{"error": "<message>"}`:

| Status | When                                                                              |
| ------ | --------------------------------------------------------------------------------- |
| `400`  | Invalid signature, invalid JSON, duplicate object keys, or the wrong body shape   |
| `404`  | Unknown route                                                                     |
| `405`  | Any method other than `POST` on the four endpoints (with `Allow: POST`)            |
| `413`  | Body over 1 MB                                                                    |

## Configuration

| Setting                | Where                         | Default                         |
| ---------------------- | ----------------------------- | ------------------------------- |
| Port                   | `PORT` env var                | `4000`                          |
| Signing key            | `RIOT_SIGNING_KEY` env var    | A committed dev key (non-prod)  |
| Cipher / signer module | `config/config.exs`           | `Base64` / `HMAC`               |
| Max body size          | `config/config.exs`           | 1 MB                            |

In production (`MIX_ENV=prod`) the app refuses to boot unless
`RIOT_SIGNING_KEY` is a secret of at least 32 bytes that is not the committed
dev/test key. Generate one with `openssl rand -hex 32`. Other environments use
the public dev key, so never expose a non-prod build.

## Quality checks

```bash
mise exec -- mix test                       # unit, property-based and HTTP tests
mise exec -- mix format --check-formatted
mise exec -- mix credo --strict
mise exec -- mix dialyzer
```

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs all of these on
every push, plus an unused-dependency check and `mix hex.audit`.

## Architecture

Ports and adapters (hexagonal), kept to Elixir idioms rather than folder ceremony:

```
 Driving adapter          Core (pure functions)        Ports              Driven adapters
┌────────────────┐   ┌──────────────────────────┐   ┌───────────────┐   ┌───────────────────┐
│ RiotWeb.Router │──▶│ Riot.Encryption          │──▶│ Crypto.Cipher │◀──│ Ciphers.Base64    │
│ (Plug)         │   │ Riot.Signing             │──▶│ Crypto.Signer │◀──│ Signers.HMAC      │
└────────────────┘   │ Riot.CanonicalJSON       │   └───────────────┘   └───────────────────┘
                     └──────────────────────────┘
```

- **Ports** are behaviours that know nothing about JSON or HTTP, and take keys
  as opaque terms so keyed and asymmetric algorithms fit:
  - `Crypto.Cipher` gets a key (`nil` for Base64) and can fail. Its `decrypt`
    tells "not my ciphertext" (passed through unchanged) apart from "my
    ciphertext, but corrupt" (`400`), so an AEAD cipher never echoes tampered
    ciphertext back.
  - `Crypto.Signer` signs with `signing_key` and verifies with
    `verification_key`, which defaults to the signing key: right for HMAC, and a
    public key for something like Ed25519.
- **The core** takes the algorithm module and key as arguments and does no IO,
  so it is tested without config or a server.
- **Only `Riot.Config` reads application env**, and only `RiotWeb.Response` maps
  error reasons to HTTP status codes.
- **Swapping an algorithm** takes one new module implementing the behaviour, plus
  config. The tests prove it with two test-only adapters: `ReverseCipher` passes
  the same round-trip property, and `Ed25519Signer` (asymmetric) works through
  the HTTP endpoints with only config changed
  ([config_swap_test.exs](test/riot_web/config_swap_test.exs)).

## Design decisions and trade-offs

**Encryption preserves types.** Each top-level value is JSON-encoded, then
encrypted, so `30` decrypts back to the number `30` and nested objects come back
as objects.

**Detecting encrypted values.** A string is decrypted only if it is valid
ciphertext (strict Base64) *and* decrypts to valid JSON; anything else is
returned unchanged. Known false positive: a plain string that happens to be
Base64 of valid JSON (e.g. `"MTIz"` → `123`) gets decrypted. The robust fix is a
versioned prefix (`"enc:v1:…"`); I kept the bare format to match the spec's
examples.

**Order-independent signatures.** Values are serialized with
`Riot.CanonicalJSON` (keys sorted recursively, no whitespace, array order kept)
before signing. It is a pragmatic subset of RFC 8785: keys sort by UTF-8 bytes
rather than UTF-16 code units, `1` and `1.0` are different values, and `-0.0` is
normalized to `0.0`.

**Duplicate keys are rejected.** Parsers disagree on which duplicate wins
(Elixir keeps the first; JavaScript, Python and Go keep the last), so signing
`{"a":1,"a":2}` could let another system read a different value than the one
that was signed.

**Signatures** are HMAC-SHA256 in lowercase hex, compared in constant time
(`Plug.Crypto.secure_compare/2`) and case-sensitively. `/sign` returns only
`{"signature": …}`, as in the spec's examples.

**Input handling.**
- `/encrypt` and `/decrypt` require a JSON object, since "properties at depth 1"
  only makes sense for objects. `/sign` and `/verify`'s `data` accept any JSON
  value.
- `Plug.Parsers` is not used: it wraps non-object bodies as `{"_json": …}`,
  which is ambiguous with a real `_json` key.
- `Content-Type` is not enforced, so plain `curl -d` works.
- Request payloads are never logged.
- Bandit serves HTTP/1.1 only. HTTP/2 isn't needed, and Bandit 1.12.5 has an
  open HTTP/2 slow-client advisory (EEF-CVE-2026-105659) with no fixed release
  yet. For the same reason, `mix hex.audit` doesn't fail CI for now.

**The docs are a hand-written spec, tested against the API.** For four endpoints
an OpenAPI library isn't worth it. Instead,
[docs_test.exs](test/riot_web/docs_test.exs) sends every documented example to
the router and checks the documented status and body, so the docs can't drift
silently. Swagger UI loads from jsDelivr, pinned with Subresource Integrity
hashes, so `/docs` needs internet access (the API itself does not).

## With more time

- A real AEAD cipher (AES-256-GCM) with a versioned ciphertext prefix and key IDs
  for rotation. The cipher port already supports this: it is a new adapter plus
  config.
- Accepting several verification keys during signing-key rotation.
- Full RFC 8785 canonicalization.
- Rate limiting, request IDs, telemetry metrics, and a release/Docker image.
