defmodule Hermes.MixProject do
  use Mix.Project

  def project do
    [
      app: :hermes,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases(),
      default_release: :server
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :logger_file_backend, :crypto, :httpoison],
      mod: {Hermes.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:exldap, "~> 0.6"},
      {:ecto_sql, "~> 3.4"},
      {:ecto_enum, "~> 1.4"},
      {:postgrex, ">= 0.0.0"},
      {:httpoison, "~> 1.8"},
      {:quantum, "~> 3.0"},
      {:logger_file_backend, "~> 0.0.12"},
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "local.prerequisites": ["local.hex --force", "local.rebar --force"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  # Run "mix help release" to learn about releases.
  defp releases do
    [
      server: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        validate_compile_env: false
      ],
      server_windows: [
        include_executables_for: [:windows],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end
end
