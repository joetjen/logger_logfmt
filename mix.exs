defmodule LoggerLogfmt.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/joetjen/logger_logfmt"

  # `mix precommit` includes `test` as a step; without this, Mix runs
  # the whole alias chain (including `mix test`) in :dev, and `mix test`
  # itself refuses to run outside :test when invoked as a sub-task
  # rather than the top-level command.
  def cli do
    [preferred_envs: [precommit: :test]]
  end

  def project do
    [
      app: :logger_logfmt,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      aliases: aliases(),

      # Docs
      name: "LoggerLogfmt",
      description: "A logfmt formatter for Elixir's Logger",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dev/Test dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.39.1", only: :dev, runtime: false},

      # Test dependencies
      {:stream_data, "~> 1.4", only: :test}
    ]
  end

  # Fast/cheap checks first so a broken commit fails quickly; dialyzer
  # (slowest, especially its first PLT build) runs last.
  defp aliases do
    [
      precommit: [
        "format",
        "compile --warnings-as-errors",
        "credo --strict",
        "sobelow",
        "test",
        "dialyzer"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "QUICKSTART.md", "USAGE_GUIDE.md", "EXAMPLES.md", "CONTRIBUTING.md", "LICENSE"],
      source_ref: @version,
      source_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp package do
    [
      name: "logger_logfmt",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end
end
