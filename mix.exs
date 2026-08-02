defmodule Elex.MixProject do
  use Mix.Project

  def project do
    [
      app: :elex,
      version: "0.2.2",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [summary: [threshold: 80]],
      elixirc_options: elixirc_options(Mix.env()),
      description:
        "Parse, validate, and evaluate mathematical and logical expressions with variables, functions, and optional Ash integration.",
      package: package(),
      # Docs
      name: "Elex",
      source_url: "https://github.com/bandesz/elex",
      docs: [
        main: "readme",
        extras: [
          "README.md": [title: "Overview"],
          "guides/getting-started.md": [title: "Getting Started"],
          "guides/expression-language.md": [title: "Expression Language"],
          "guides/functions.md": [title: "Functions"],
          "guides/ash-integration.md": [title: "Ash Integration"],
          "guides/advanced.md": [title: "Advanced Topics"],
          "CHANGELOG.md": [title: "Changelog"],
          LICENSE: [title: "License"]
        ],
        groups_for_modules: [
          "Core API": [Elex, Elex.Context, Elex.Variable],
          "Parsing & Evaluation": [
            Elex.Parser,
            Elex.Evaluator,
            Elex.Validator,
            Elex.Parser.ErrorFormatter
          ],
          Extensions: [Elex.Function, Elex.AshValidation, Elex.Inverter, Elex.Labels],
          "Built-in Functions": ~r/Elex\.Functions\./
        ]
      ],
      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  defp elixirc_options(_), do: [warnings_as_errors: true]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test, "test.ci": :test, "docs.ci": :dev]
    ]
  end

  defp package do
    [
      name: "elex",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/bandesz/elex",
        "Changelog" => "https://github.com/bandesz/elex/blob/main/CHANGELOG.md"
      },
      maintainers: ["bandesz"],
      files: ~w(lib guides mix.exs mix.lock README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.0 or ~> 3.0"},
      {:nimble_parsec, "~> 1.0"},
      {:ash, "~> 3.22", optional: true},
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
        "deps.audit --ignore-file .audit_ignore",
        "docs.ci"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "credo --strict",
        "sobelow --config",
        "deps.audit --ignore-file .audit_ignore",
        "test"
      ],
      test: ["test --warnings-as-errors"],
      "test.ci": ["test --cover --warnings-as-errors"],
      "docs.ci": ["docs --warnings-as-errors"]
    ]
  end
end
