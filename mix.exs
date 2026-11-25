defmodule GigTypst.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :gig_typst,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Typst text and maths as labels for Giggly's titles.",
      package: [
        licenses: ["MIT", "OFL-1.1"],
        files: ["lib", "priv", "mix.exs", ".formatter.exs", "README.md", "LICENSE"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Giggly is taken by path from its main checkout, which holds the label protocol, until that
  # protocol is released; a Hex release of this package waits for Giggly's. Scales, which
  # `label_math/2` writes breaks with, from the same path Giggly takes it.
  defp deps do
    [
      {:giggly, path: "/home/srowley/repos/giggly"},
      {:scales, "~> 0.2.0", path: "/home/srowley/repos/scales"},
      {:typst, "~> 0.4.6"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
