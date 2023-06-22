defmodule Inngest.MixProject do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :inngest,
      version: @version,
      elixir: "~> 1.14",
      # build_embedded: Mix.env() == :prod,
      # start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),

      # Docs
      name: "Inngest",
      docs: docs(),
      description: "Elixir SDK for Inngest",
      homepage_url: "https://inngest.com"
    ]
  end

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
      # main: "",
      source_ref: "v#{@version}",
      source_url: "https://github.com/darwin67/ex-inngest"
      # extra_section: "GUIDES",
      # extras: extras(),
      # nest_modules_by_prefix: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.10"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.0"},
      # {:bandit, "~> 0.6"},

      # dev / test
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
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
