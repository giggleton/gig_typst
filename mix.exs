defmodule GigTypst.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/giggleton/gig_typst"

  def project do
    [
      app: :gig_typst,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Typst text and maths as labels for Giggly's titles.",
      source_url: @source_url,
      package: [
        licenses: ["MIT", "OFL-1.1"],
        links: %{"GitHub" => @source_url},
        files: ["lib", "priv", "mix.exs", ".formatter.exs", "README.md", "LICENSE"]
      ],
      docs: [main: "GigTypst", source_ref: "v#{@version}"]
    ]
  end

  # `mix quality` runs in test, the environment its `mix test` step needs.
  def cli do
    [preferred_envs: [quality: :test]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Giggly holds the label protocol this package implements; Scales is what `label_math/2`
  # writes breaks with.
  defp deps do
    [
      {:giggly, "~> 0.2.0"},
      {:scales, "~> 0.2.0"},
      {:typst, "~> 0.4.6"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  # The commit gate: run bare before every commit; it stops at the first step that fails.
  defp aliases do
    [
      quality: [
        "format --check-formatted",
        "hex.audit",
        "compile --warnings-as-errors",
        "test --warnings-as-errors",
        "credo --strict"
      ]
    ]
  end
end
