defmodule Inngest.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()

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
      source_url: "https://github.com/darwin67/ex_inngest",
      description: "Elixir SDK for Inngest",
      homepage_url: "https://inngest.com",
      docs: [
        main: "Inngest",
        extras: ["README.md", "LICENSE", "CHANGELOG.md"],
        authors: ["Darwin Wu"]
        # source_ref: "v#{@version}",
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Darwin Wu"],
      licenses: ["GPL-3.0-or-later"],
      links: %{github: "https://github.com/darwin67/ex_inngest"},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:jason, "~> 1.4"},
      # JSON Canonicalization Scheme (JCS)
      # {:jcs, git: "https://github.com/pzingg/jcs.git", ref: "24196d27ae7a9d1ab116e004d0aac07360ae4000"},
      {:plug, "~> 1.14"},
      {:timex, "~> 3.7"},

      # dev / test
      {:plug_cowboy, "~> 2.0", only: :dev},
      {:phoenix, "~> 1.6", only: [:dev, :test]},
      # {:bandit, "~> 0.6", only: :dev},
      {:tz, "~> 0.26", only: :dev},
      {:tz_extra, "~> 0.26", only: :dev},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dotenv, "~> 3.0", only: [:dev]},
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
