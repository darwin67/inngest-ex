defmodule Inngest.MixProject do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :inngest,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      deps: deps(),
      aliases: aliases(),
      package: package(),

      # tests
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Docs
      name: "Inngest",
      docs: docs(),
      description: "Elixir SDK for Inngest",
      homepage_url: "https://inngest.com"
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Darwin Wu"],
      licenses: ["GPL-3.0-or-later"],
      links: %{github: "https://github.com/darwin67/ex-inngest"},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: "https://github.com/darwin67/ex-inngest"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.10"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.14"},
      {:timex, "~> 3.7"},

      # dev / test
      {:plug_cowboy, "~> 2.0", only: :dev},
      # {:bandit, "~> 0.6", only: :dev},
      {:tz, "~> 0.26", only: :dev},
      {:tz_extra, "~> 0.26", only: :dev},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp aliases() do
    [
      lint: ["credo"],
      "fmt:check": [
        "format --check-formatted mix.exs 'lib/**/*.{ex,exs}' 'test/**/*.{ex,exs}'"
      ],
      dev: "run --no-halt dev.exs"
    ]
  end
end
