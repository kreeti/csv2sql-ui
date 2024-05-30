defmodule Dashboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :dashboard,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "Csv2sqlDashboard",
      description: "Csv2SqlDashboard is a blazing fast fully automated tool to load huge CSV files into a RDBMS.",
      package: package(),
      source_url: "https://github.com/kreeti/csv2sql-ui"
    ]
  end

  defp package() do
    [
      name: "csv2sqldashboard",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/kreeti/csv2sql-ui"
      }
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Dashboard.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_view, "~> 0.20.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:ecto, "~> 3.11.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:csv2sql, "~> 0.1.0"},
      {:nanoid, "~> 2.1.0"},
      {:ex_doc, "~> 0.33.0"},

      # Development Deps
      {:phoenix_live_reload, "~> 1.5.3", only: :dev},
      {:dart_sass, "~> 0.7.0", runtime: Mix.env() == :dev},
      {:esbuild, "~> 0.8.1", runtime: Mix.env() == :dev},
      {:floki, ">= 0.36.1", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      "assets.deploy": [
        "esbuild default --minify",
        "sass default --no-source-map --style=compressed",
        "phx.digest"
      ]
    ]
  end
end
