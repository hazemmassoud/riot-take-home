defmodule Riot.MixProject do
  use Mix.Project

  def project do
    [
      app: :riot,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Test-only adapters and generators are not part of the app.
      test_coverage: [ignore_modules: [~r/^Riot\.Test\./, Riot.JSONGenerators]],
      # PLTs live in priv/plts so CI can cache them between runs.
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Riot.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.5"},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
