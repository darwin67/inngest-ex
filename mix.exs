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
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:tesla, "~> 1.4.0"},
      {:hackney, "~> 1.10"},
      {:jason, "~> 1.4"}
    ]
  end
end
