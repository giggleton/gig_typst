defmodule GigTypst.Document do
  @moduledoc false

  # The Typst document a label is laid out by, and what its pages give back (`Giggly.Label`'s
  # layout for `GigTypst.Content`).
  #
  # Two pages. The first is the label alone: a page as big as what is on it, no margin and no
  # fill, its text's edges at its glyphs' bounds, so the page is the label's box; on it, after the
  # label, a box of no size at the label's baseline, whose place Typst knows only once the page is
  # laid out. The second page carries what the first cannot: its height is that place's depth
  # below the first page's top, the label's ascent, a point added so no page is empty; its width is
  # a point and a point more where the text's family has no font, two more where the maths'
  # family has none, as Typst measures a family it lacks with `fallback: false` as no width at
  # all, where it would otherwise draw in another font and say nothing Elixir hears.
  #
  # The source goes into the document as a Typst string, which `eval` reads in its mode, so
  # nothing in it can close the brackets round it. `Typst.render_to_svg/3` runs the document
  # through EEx first, so every `<%` is written `<%%`.

  alias Giggly.Label.{Layout, Style}
  alias GigTypst.Content

  @marker "gig-typst-baseline"

  # Liberation Sans, which this package ships, then the directories a label names.
  @fonts_dir "fonts"

  # The layout of `content` in `style`: its box, from the first page's size and the second's
  # height, and the first page's SVG, its root's size left out so it fills the box it is drawn in.
  #
  # An empty source is a box of no size drawing nothing, where Typst would give its page a point
  # each way.
  @spec layout(Content.t(), Style.t()) :: Layout.t()
  def layout(%Content{source: ""}, %Style{}),
    do: %Layout{width: 0.0, ascent: 0.0, descent: 0.0, svg: ""}

  def layout(%Content{} = content, %Style{} = style) do
    family = family(style.family)

    pages =
      content
      |> source(style, family)
      |> String.replace("<%", "<%%")
      |> Typst.render_to_svg([], extra_fonts: [fonts_dir() | content.font_dirs])

    case pages do
      {:ok, [label, carrier]} ->
        {width, height} = page_size(label)
        {flags, ascent_and_point} = page_size(carrier)
        check_families(round(flags - 1.0), family, content)
        ascent = ascent_and_point - 1.0

        %Layout{width: width, ascent: ascent, descent: height - ascent, svg: unsized(label)}

      {:error, reason} ->
        raise ArgumentError,
              "Typst could not lay out #{inspect(content.source)}: #{reason}"
    end
  end

  # The font Typst sets a family in: Giggly's default and R's generic names as the fonts this
  # package and Typst ship, any other by its own name.
  defp family(family) when family in ["", "sans"], do: "Liberation Sans"
  defp family("serif"), do: "New Computer Modern"
  defp family("mono"), do: "DejaVu Sans Mono"
  defp family(family), do: family

  defp source(content, style, family) do
    """
    #set page(width: auto, height: auto, margin: 0pt, fill: none)
    #set text(size: #{points(style.size)}, fill: rgb(#{string(color(style))}), font: #{string(family)}, weight: #{string(weight(style.face))}, style: #{string(slant(style.face))}, top-edge: "bounds", bottom-edge: "bounds")
    #show math.equation: set text(font: #{string(content.math_family)})
    #box[#{body(content)}#box(width: 0pt, height: 0pt)<#{@marker}>]
    #context page(
      width: 1pt + #{missing(family, "1pt")} + #{missing(content.math_family, "2pt")},
      height: locate(<#{@marker}>).position().y + 1pt,
      fill: none,
    )[]
    """
  end

  defp body(%Content{mode: :markup, source: source}),
    do: "#eval(#{string(source)}, mode: \"markup\")"

  defp body(%Content{mode: :inline_math, source: source}),
    do: "#math.equation(block: false, eval(#{string(source)}, mode: \"math\"))"

  defp body(%Content{mode: :display_math, source: source}),
    do: "#math.equation(block: false, math.display(eval(#{string(source)}, mode: \"math\")))"

  # What a family adds to the second page's width: `amount` where Typst has no font for it.
  defp missing(family, amount) do
    "(if measure(text(font: #{string(family)}, fallback: false)[M]).width == 0pt " <>
      "{ #{amount} } else { 0pt })"
  end

  defp check_families(flags, family, content) do
    missing =
      Enum.filter(
        [{1, family}, {2, content.math_family}],
        fn {bit, _family} -> Bitwise.band(flags, bit) != 0 end
      )

    case missing do
      [] ->
        :ok

      [{_bit, name} | _rest] ->
        raise ArgumentError,
              "Typst found no font of the family #{inspect(name)}, among the fonts " <>
                "GigTypst ships, Typst's own, the machine's installed fonts and font_dirs: " <>
                inspect(content.font_dirs)
    end
  end

  defp weight(face) when face in [:bold, :bold_italic], do: "bold"
  defp weight(_face), do: "regular"

  defp slant(face) when face in [:italic, :bold_italic], do: "italic"
  defp slant(_face), do: "normal"

  # The style's colour with its opacity as Typst's `#RRGGBBAA`, the alpha a byte.
  defp color(%Style{color: color, opacity: opacity}) do
    alpha =
      (opacity * 255)
      |> round()
      |> Integer.to_string(16)
      |> String.pad_leading(2, "0")

    color <> alpha
  end

  defp points(size), do: :erlang.float_to_binary(size / 1, decimals: 6) <> "pt"

  # A Typst string literal of `text`.
  defp string(text) do
    escaped =
      text
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")
      |> String.replace("\r", "\\r")

    "\"" <> escaped <> "\""
  end

  # A page's width and height in points, as its root `<svg>` gives them.
  defp page_size(svg) do
    [_root, width, height] = Regex.run(~r/<svg[^>]* width="([\d.]+)pt" height="([\d.]+)pt"/, svg)
    {number(width), number(height)}
  end

  defp number(text) do
    {value, ""} = Float.parse(text)
    value
  end

  # The page's SVG with its root's width and height left out, its `viewBox` kept.
  defp unsized(svg),
    do:
      Regex.replace(~r/(<svg[^>]*?) width="[\d.]+pt" height="[\d.]+pt"/, svg, "\\1",
        global: false
      )

  defp fonts_dir, do: Application.app_dir(:gig_typst, ["priv", @fonts_dir])
end
