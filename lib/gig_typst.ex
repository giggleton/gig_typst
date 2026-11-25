defmodule GigTypst do
  @moduledoc """
  Typst text and maths as labels for Giggly: a plot's title, an axis's or a legend's, set by
  [Typst](https://typst.app) and drawn into the plot's SVG.

  `text/2` and `math/2` each return a `GigTypst.Content`, which goes wherever Giggly takes a
  label another library lays out: any `Giggly.Plot.labs/2` title, a scale's or a secondary axis's
  `name:`, a guide's `title:`, a text or label annotation's `label:`, a scale's `labels:`, which
  `label_math/2` writes from each break, a facet's strips, through a `labeller:` function such
  as `&GigTypst.math/1`, and a text or label layer's rows, through `label_with:`.

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

  @doc """
  A scale's labels function setting each break as Typst maths, as R's `label_math()` does:
  `formula` is handed each break written as text and returns the formula, which `math/2` lays
  out. `labels: GigTypst.label_math(fn text -> "10^" <> text end)` labels the breaks 1, 2 and 3
  as 10¹, 10² and 10³.

  ## Options

    * `:format` — a function handed every break at once, returning each one's text, or `nil` for
      one with no label, as `Scales.Labels`' functions do: `&Scales.Labels.scientific/1`, or
      `fn breaks -> breaks |> Enum.map(&:math.log10/1) |> Scales.Labels.plain() end` to label a
      log axis's breaks by their powers. By default numbers are written by
      `Scales.Labels.plain/1`, as a Giggly axis writes its own, and a discrete scale's strings as
      they are.
    * `:inline`, `:font_dirs` and `:math_family` — as `math/2` takes them.

  A missing break, or one `:format` gives no text, has no label, and `formula` is not called
  for it.

  ## Examples

      iex> labeller = GigTypst.label_math(fn text -> "x_" <> text end)
      iex> labeller.([1.0, 2.0]) |> Enum.map(fn content -> content.source end)
      ["x_1", "x_2"]

      iex> labeller = GigTypst.label_math(fn text -> text end)
      iex> labeller.(["alpha", nil]) |> Enum.map(fn content -> content && content.source end)
      ["alpha", nil]
  """
  @spec label_math((String.t() -> String.t()), keyword()) :: ([term()] -> [Content.t() | nil])
  def label_math(formula, options \\ []) when is_function(formula, 1) and is_list(options) do
    {format, math_options} = Keyword.pop(options, :format, &written/1)

    unless is_function(format, 1),
      do:
        raise(
          ArgumentError,
          "expected :format to be a function of one argument, got: #{inspect(format)}"
        )

    fn breaks ->
      format
      |> formatted(breaks)
      |> Enum.map(fn text -> text && math(formula.(text), math_options) end)
    end
  end

  # What `format` writes `breaks` as, which must be a string or `nil` for each.
  defp formatted(format, breaks) do
    texts = format.(breaks)

    if is_list(texts) and length(texts) == length(breaks) and
         Enum.all?(texts, fn text -> is_binary(text) or is_nil(text) end) do
      texts
    else
      raise ArgumentError,
            "expected :format to return a string or nil for each of the breaks " <>
              "#{inspect(breaks)}, got: #{inspect(texts)}"
    end
  end

  # Breaks written as text by default: numbers together by `Scales.Labels.plain/1`, as a Giggly
  # axis writes them, strings as they are, a missing one none.
  defp written(breaks) do
    if Enum.all?(breaks, fn break -> is_number(break) or is_nil(break) end),
      do: plain(breaks),
      else: Enum.map(breaks, &as_text/1)
  end

  defp plain(breaks) do
    numbers = for break <- breaks, is_number(break), do: break / 1
    {texts, []} = Enum.map_reduce(breaks, Scales.Labels.plain(numbers), &placed/2)
    texts
  end

  defp placed(nil, texts), do: {nil, texts}
  defp placed(_break, [text | texts]), do: {text, texts}

  defp as_text(break) when is_binary(break) or is_nil(break), do: break

  defp as_text(break) do
    raise ArgumentError,
          "label_math/2 writes numbers or strings, got: #{inspect(break)}; give :format to " <>
            "write it"
  end
end
