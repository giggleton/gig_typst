# GigTypst

[Typst](https://typst.app) text and maths as labels for
[Giggly](https://github.com/giggleton/giggly), the grammar-of-graphics plotting library for
Elixir: a plot's title, an axis's or a legend's, set by Typst and drawn into the plot's SVG.

It is also a worked example of a Giggly label engine: a struct implementing `Giggly.Label`,
which goes wherever Giggly takes a title's string.

## Installation

```elixir
def deps do
  [
    {:giggly, "~> 0.2.0"},
    {:gig_typst, "~> 0.1.0"}
  ]
end
```

It draws through the [`typst`](https://hex.pm/packages/typst) package, whose native library is
downloaded precompiled.

## Use

```elixir
table
|> Giggly.Plot.new(%{x: :dose, y: :response})
|> Giggly.Plot.geom_point()
|> Giggly.Plot.labs(
  title: GigTypst.text("Response to *each* dose"),
  x: GigTypst.math("log_10 \"dose\"", inline: true),
  y: GigTypst.math("sigma^2 / n")
)
|> Giggly.to_svg()
```

- `GigTypst.text/2` takes Typst markup: text, `*strong*`, `_emphasised_`, `$x^2$` maths among
  it, `\` breaking a line.
- `GigTypst.math/2` takes maths as written between `$` signs, set as a formula standing on its
  own unless `inline: true`.

A label goes in any `labs/2` title, a scale's or a secondary axis's `name:`, and a guide's
`title:`. The theme decides its size, colour, opacity, font family and face, where it goes and
how it turns; Typst lays out what is inside it.

A label also goes in a text annotation's `label:`, at a place in the data, one label or a list of
them, one per annotation:

```elixir
plot
|> Giggly.Plot.annotate(:text,
  x: 2.5,
  y: 30,
  label: GigTypst.math("hat(y) = beta_0 + beta_1 x"),
  size: 5,
  hjust: 0
)
```

The annotation decides its size, colour, alpha, family and face, its angle and its
justification, which is by the label's whole box: `vjust: 0` sets the bottom of its glyphs on
the place. `annotate(:label, ...)` sets it on a box, as `geom_label` boxes a string, the box
the label's own padded on every side.

A scale's `labels:` takes labels too, in its list or map, or from a function.
`GigTypst.label_math/2`, R's `label_math()`, makes that function: it writes each break as text,
as a Giggly axis writes its own, hands it to yours, and sets what yours returns as maths.

```elixir
plot
|> Giggly.Plot.scale_x_log10(
  labels:
    GigTypst.label_math(fn text -> "10^" <> text end,
      format: fn breaks -> breaks |> Enum.map(&:math.log10/1) |> Scales.Labels.plain() end
    )
)
|> Giggly.Plot.scale_y_continuous(labels: GigTypst.label_math(fn text -> "y_" <> text end))
|> Giggly.Plot.scale_color_discrete(labels: GigTypst.label_math(fn text -> text end))
```

`format:` takes any function writing the breaks as text, `Scales.Labels`' among them; a
discrete scale's levels, already text, are handed over as they are, so `"alpha"` is α. Where an
axis's labels hold a Typst label, the strings beside it are boxed by their glyphs, as R boxes the
strings of an expression vector.

A facet's strips take labels from a `labeller:` function or map, so `&GigTypst.math/1` sets each
strip as maths, as R's `label_parsed` parses it:

```elixir
plot
|> Giggly.Plot.facet_wrap(:term, labeller: &GigTypst.math/1)
```

A function writing each label into a formula does what R's `label_bquote` does:
`labeller: fn order -> GigTypst.math("x^" <> order) end`.

Giggly refuses a Typst label where its labeller writes text with it: `:both` or `:context`
naming the facet beside it, `:wrap`, and `multi_line: false` joining a panel's labels.

A column of formulas draws as maths through `label_with:` on `geom_text/3` and `geom_label/3`,
as R's `parse = TRUE` parses one:

```elixir
plot
|> Giggly.Plot.geom_text(%{label: :formula}, label_with: &GigTypst.math/1)
```

Each row's label is handed over as text as the plot is drawn, a number as R writes it and a
missing one never. The legend's keys stay the letter "a", as R's do, and Giggly refuses a
`lineheight:` or the `:symbol` face beside it.

## Fonts

The theme's family names a font: `""` and `"sans"` are Liberation Sans, which this package
ships, so a label measures as Giggly's own text does; `"serif"` is New Computer Modern and
`"mono"` DejaVu Sans Mono, both shipped with Typst; any other name is the font of that name,
looked for in the directories `font_dirs:` lists and among the machine's installed fonts. Maths
is set in New Computer Modern Math unless `math_family:` names another. A family no font is found
for raises, naming it.

Typst keeps the fonts it scanned for one list of directories at a time, so pass the same
`font_dirs:` to every label.

## How a Typst label differs from a string

- Its box is its glyphs' own bounds, where a string's is its font's ascent of "M" and descent,
  so a title can take a fraction of a point more or less room.
- Its lines break where its markup breaks them, never at the theme's line spacing.
- It is drawn as Typst's outlines, whether `Giggly.to_svg/2` writes text as text or as outlines.

## License

The code is MIT (`LICENSE`). The Liberation Sans fonts in `priv/fonts` are under the SIL Open
Font License 1.1, Reserved Font Name "Liberation" (`priv/fonts/OFL.txt`); the Lato font in
`test/fonts` likewise, Reserved Font Name "Lato" (`test/fonts/Lato-OFL.txt`).
