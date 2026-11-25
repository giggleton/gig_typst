# GigTypst

[Typst](https://typst.app) text and maths as labels for
[Giggly](https://github.com/giggleton/giggly), the grammar-of-graphics plotting library for
Elixir: a plot's title, an axis's or a legend's, set by Typst and drawn into the plot's SVG.

It is also a worked example of a Giggly label engine: a struct implementing `Giggly.Label`,
which goes wherever Giggly takes a title's string.

## Installation

GigTypst needs Giggly's label protocol, which is not yet released. Until it is, depend on Giggly
and GigTypst by path:

```elixir
def deps do
  [
    {:giggly, path: "../giggly"},
    {:gig_typst, path: "../gig_typst"}
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

## Licence

The code is MIT (`LICENSE`). The Liberation Sans fonts in `priv/fonts` are under the SIL Open
Font License 1.1, Reserved Font Name "Liberation" (`priv/fonts/OFL.txt`); the Lato font in
`test/fonts` likewise, Reserved Font Name "Lato" (`test/fonts/Lato-OFL.txt`).
