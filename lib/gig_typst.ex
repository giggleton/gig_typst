defmodule GigTypst do
  @moduledoc """
  Typst text and maths as labels for Giggly: a plot's title, an axis's or a legend's, set by
  [Typst](https://typst.app) and drawn into the plot's SVG.

  `text/2` and `math/2` each return a `GigTypst.Content`, which goes wherever Giggly takes a
  title's string: any `Giggly.Plot.labs/2` title, a scale's or a secondary axis's `name:`, a
  guide's `title:`.

      Giggly.Plot.new(table, %{x: :x, y: :y})
      |> Giggly.Plot.geom_point()
      |> Giggly.Plot.labs(
        title: GigTypst.text("Growth of *every* sample"),
        y: GigTypst.math("sigma^2 / n")
      )
      |> Giggly.to_svg()

  The theme still decides the title's size, colour, opacity, font family and face, and where it
  goes and how it turns; Typst lays out what is inside it. A label's box is its glyphs' own
  bounds, so a title can take a fraction of a point more or less room than the same text as a
  string; its lines break where its markup breaks them, and it is drawn as Typst's outlines.

  ## Fonts

  The theme's family names a font:

    * `""` and `"sans"` — Liberation Sans, which this package ships, so a label measures as
      Giggly's own text does;
    * `"serif"` — New Computer Modern, and `"mono"` — DejaVu Sans Mono, both shipped with Typst;
    * any other — the font of that name, from the directories `font_dirs:` lists or the machine's
      installed fonts.

  Maths is set in New Computer Modern Math unless `math_family:` names another. A family no font
  is found for raises, naming it, where Typst would draw in another without a word.
  """

  alias GigTypst.Content

  @doc """
  A label of Typst markup: text, `*strong*` and `_emphasised_`, `$x^2$` maths among it, a line
  break with `\\`.

  ## Options

    * `:font_dirs` — directories of font files to look for a family in, beside the machine's
      installed fonts; `[]` unless given. Pass the same list to every label: Typst keeps the
      fonts it scanned for one list at a time.
    * `:math_family` — the font any maths in it is set in, `"New Computer Modern Math"` unless
      given.

  ## Examples

      iex> GigTypst.text("Growth of *every* sample")
      %GigTypst.Content{
        source: "Growth of *every* sample",
        mode: :markup,
        font_dirs: [],
        math_family: "New Computer Modern Math"
      }
  """
  @spec text(String.t(), keyword()) :: Content.t()
  def text(markup, options \\ []) when is_binary(markup) and is_list(options),
    do: Content.new(markup, :markup, options)

  @doc """
  A label of Typst maths, as written between `$` signs: `"sigma^2 / n"`, `"sum_(i=1)^n x_i"`.

  ## Options

    * `:inline` — `true` to set it as maths within a line, smaller and flatter, `false` to set it
      as a formula standing on its own; `false` unless given.
    * `:font_dirs` and `:math_family` — as `text/2` takes them.

  ## Examples

      iex> GigTypst.math("sigma^2 / n", inline: true)
      %GigTypst.Content{
        source: "sigma^2 / n",
        mode: :inline_math,
        font_dirs: [],
        math_family: "New Computer Modern Math"
      }
  """
  @spec math(String.t(), keyword()) :: Content.t()
  def math(formula, options \\ []) when is_binary(formula) and is_list(options) do
    {inline, options} = Keyword.pop(options, :inline, false)

    unless is_boolean(inline),
      do: raise(ArgumentError, "expected :inline to be true or false, got: #{inspect(inline)}")

    Content.new(formula, if(inline, do: :inline_math, else: :display_math), options)
  end
end
