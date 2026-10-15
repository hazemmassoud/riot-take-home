defmodule Riot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Riot.Config.server?() do
        # HTTP/2 is not needed by this API, and Bandit 1.12.5 has an open HTTP/2
        # slow-client advisory (EEF-CVE-2026-105659), so serve HTTP/1.1 only.
        [
          {Bandit,
           plug: RiotWeb.Router, port: Riot.Config.port(), http_2_options: [enabled: false]}
        ]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Riot.Supervisor)
  end
end
