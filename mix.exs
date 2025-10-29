defmodule Elex.MixProject do
  use Mix.Project

  def project do
    [
      app: :elex,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [summary: [threshold: 80]],
      # Docs
      name: "Elex",
      source_url: "https://github.com/bandesz/elex",
      docs: [
        main: "Elex",
        extras: ["README.md"]
      ],
      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.0"},
      {:nimble_parsec, "~> 1.0"},
      {:ash, "~> 3.0", optional: true},
      # Dev/Test dependencies
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "sobelow --config",
        "deps.unlock --check-unused",
        "deps.audit"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "format",
        "credo --strict",
        "sobelow --config",
        "deps.unlock --unused",
        "deps.audit",
        "test"
      ],
      "test.ci": ["test --cover --warnings-as-errors"]
    ]
  end
end
