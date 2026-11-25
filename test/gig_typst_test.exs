defmodule GigTypstTest do
  use ExUnit.Case, async: true

  doctest GigTypst

  alias Giggly.Label.{Layout, Style}

  @style %Style{size: 11.0, color: "#1A2B3C", opacity: 0.5, family: "", face: :plain}

  defp layout(content, style \\ @style), do: Giggly.Label.layout(content, style)

  describe "text/2 and math/2" do
    test "a label's options are checked when it is made, naming the one refused" do
      for {make, message} <- [
            {fn -> GigTypst.math("x", inline: :yes) end, ":inline to be true or false"},
            {fn -> GigTypst.text("x", font_dirs: "fonts") end,
             ":font_dirs to be a list of paths"},
            {fn -> GigTypst.text("x", math_family: :fira) end, ":math_family to be a string"},
            {fn -> GigTypst.text("x", size: 12) end, "unknown keys [:size]"}
          ] do
        error = assert_raise ArgumentError, make
        assert error.message =~ message
      end
    end

    test "maths stands on its own unless inline: true" do
      assert {GigTypst.math("x").mode, GigTypst.math("x", inline: true).mode} ===
               {:display_math, :inline_math}
    end
  end

  describe "the layout Giggly asks for" do
    # Liberation Sans, which this package ships, is the font Giggly's own default family is
    # measured from, so a label of plain text is as wide as Giggly measures the string, to the
    # hundredths of a point Typst's and vdiffr's sums of advances differ by. Giggly measures a
    # bold string as plain where no font is registered, as vdiffr does, so only plain text is
    # compared.
    test "plain text in Giggly's default family is as wide as Giggly measures it" do
      for text <- ["Fuel economy", "Miles per gallon"] do
        %Layout{width: width} = layout(GigTypst.text(text))
        assert_in_delta width, Giggly.Font.width(text, 11.0, "", :plain, false), 0.02
      end
    end

    # Its box is its glyphs' bounds: "Fuel economy" rises to the top of its "F" and "l" and
    # reaches down to the foot of its "y", which Liberation Sans's descent passes.
    test "a label's box is its glyphs' bounds about its baseline" do
      %Layout{ascent: ascent, descent: descent} = layout(GigTypst.text("Fuel economy"))
      %Layout{ascent: flat_ascent, descent: flat_descent} = layout(GigTypst.text("ace"))

      assert ascent > flat_ascent and descent > flat_descent and flat_descent < 0.25
    end

    test "its drawing is Typst's page with its size left out, so it fills the box it is drawn in" do
      %Layout{svg: svg, width: width, ascent: ascent, descent: descent} =
        layout(GigTypst.text("Fu"))

      [root] = Regex.run(~r/<svg[^>]*>/, IO.iodata_to_binary(svg))
      [_box, box_width, box_height] = Regex.run(~r/viewBox="0 0 ([\d.]+) ([\d.]+)"/, root)

      refute root =~ ~r/ (width|height)=/
      assert_in_delta String.to_float(box_width), width, 1.0e-6
      assert_in_delta String.to_float(box_height), ascent + descent, 1.0e-6
    end

    # Liberation Sans's italic faces share their upright twins' advances, so the faces are told
    # apart by the glyphs drawn, each face's outlines its own.
    test "the style's colour and opacity are the glyphs' fill, and its face their font's" do
      drawings =
        Enum.map([:plain, :bold, :italic, :bold_italic], fn face ->
          %Layout{svg: svg} = layout(GigTypst.text("Fu"), %{@style | face: face})
          IO.iodata_to_binary(svg)
        end)

      assert Enum.all?(drawings, fn svg -> svg =~ ~s(fill="#1a2b3c80") end)

      outlines =
        Enum.map(drawings, fn svg -> Regex.scan(~r/<path[^>]* d="([^"]+)"/, svg) end)

      assert outlines |> Enum.uniq() |> length() == 4
    end

    test "R's generic families are fonts Typst or this package ships" do
      widths =
        Enum.map(["", "sans", "serif", "mono"], fn family ->
          layout(GigTypst.text("Family"), %{@style | family: family}).width
        end)

      [default, sans, serif, mono] = widths
      assert default == sans and serif != sans and mono != sans and mono != serif
    end

    test "a family found only in a directory the label names is laid out in it" do
      lato = GigTypst.text("Family", font_dirs: [Path.expand("test/fonts")])

      assert layout(lato, %{@style | family: "Lato"}).width !=
               layout(GigTypst.text("Family")).width
    end

    test "maths standing on its own is taller than within a line" do
      inline = layout(GigTypst.math("sum_(i=1)^n x_i", inline: true))
      display = layout(GigTypst.math("sum_(i=1)^n x_i"))

      assert display.ascent + display.descent > inline.ascent + inline.descent
    end

    # The source reaches Typst as a string `eval` reads, so a quote or a backslash in it is
    # Typst's markup, and `Typst.render_to_svg/3` runs EEx first, so an EEx tag is drawn as
    # written, not run: `<%= 1 %>` drawn as written is far wider than the "1" running it gives.
    test "quotes, backslashes and EEx tags in a label are Typst's to read" do
      %Layout{width: tagged} = layout(GigTypst.text(~S(say "hi" \\ <%= 1 %>)))
      %Layout{width: one} = layout(GigTypst.text("1"))

      assert tagged > 10 * one
    end

    test "an empty label is a box of no size drawing nothing" do
      assert layout(GigTypst.text("")) === %Layout{
               width: 0.0,
               ascent: 0.0,
               descent: 0.0,
               svg: ""
             }
    end

    test "a family Typst has no font for raises naming it, the text's or the maths'" do
      for {content, style, family} <- [
            {GigTypst.text("x"), %{@style | family: "No Such Family"}, "No Such Family"},
            {GigTypst.math("x", math_family: "No Such Maths"), @style, "No Such Maths"}
          ] do
        error = assert_raise ArgumentError, fn -> layout(content, style) end
        assert error.message =~ "no font of the family #{inspect(family)}"
      end
    end

    test "a label Typst cannot read raises with Typst's own message" do
      error = assert_raise ArgumentError, fn -> layout(GigTypst.math("frac(1,")) end
      assert error.message =~ ~s(could not lay out "frac(1,") and error.message =~ "unclosed"
    end
  end

  describe "label_math/2" do
    defp sources(labels), do: Enum.map(labels, fn content -> content && content.source end)

    test "numbers are written together as a Giggly axis writes them, then made formulas" do
      labeller = GigTypst.label_math(fn text -> "10^" <> text end)
      assert sources(labeller.([0.0, 0.25, 0.5])) === ["10^0.00", "10^0.25", "10^0.50"]
      assert sources(labeller.([1, nil, 3])) === ["10^1", nil, "10^3"]
    end

    test "a format writes the breaks, a break it gives no text left with no label" do
      format = fn breaks ->
        Enum.map(breaks, fn break -> if break > 1, do: Integer.to_string(round(break)) end)
      end

      labeller = GigTypst.label_math(fn text -> "x_" <> text end, format: format, inline: true)
      [none, label] = labeller.([1.0, 2.0])

      assert {none, label.source, label.mode} === {nil, "x_2", :inline_math}
    end

    test "a format that is no function, or gives no text for each break, is refused" do
      assert_raise ArgumentError, ~r/:format to be a function of one argument, got: "%d"/, fn ->
        GigTypst.label_math(fn text -> text end, format: "%d")
      end

      labeller = GigTypst.label_math(fn text -> text end, format: fn _breaks -> ["one"] end)

      assert_raise ArgumentError, ~r/breaks \[1.0, 2.0\], got: \["one"\]/, fn ->
        labeller.([1.0, 2.0])
      end
    end

    test "a break neither a number nor a string needs a format" do
      labeller = GigTypst.label_math(fn text -> text end)

      assert_raise ArgumentError, ~r/writes numbers or strings, got: :a; give :format/, fn ->
        labeller.(["b", :a])
      end
    end
  end

  describe "a plot titled by Typst" do
    test "Giggly draws each label's markup, the y axis's turned" do
      svg =
        %{"x" => [1, 2, 3], "y" => [2.0, 4.0, 3.0]}
        |> Giggly.Plot.new(%{x: :x, y: :y})
        |> Giggly.Plot.geom_point()
        |> Giggly.Plot.labs(
          title: GigTypst.text("Growth of *every* sample"),
          y: GigTypst.math("sigma^2 / n")
        )
        |> Giggly.to_svg(width: 480, height: 360)
        |> IO.iodata_to_binary()

      placed =
        Regex.scan(~r/<g transform='translate\([\d.]+,[\d.]+\)( rotate\(-90\))?'>\n<svg x=/, svg)

      assert Enum.map(placed, fn [_group | turn] -> turn end) === [[" rotate(-90)"], []]
    end

    test "Giggly draws a label annotated at a place in the data, in the annotation's colour" do
      svg =
        %{"x" => [1, 2, 3], "y" => [2.0, 4.0, 3.0]}
        |> Giggly.Plot.new(%{x: :x, y: :y})
        |> Giggly.Plot.geom_point()
        |> Giggly.Plot.annotate(:text,
          x: 2,
          y: 3,
          label: GigTypst.math("x_i^2", inline: true),
          colour: "#1A2B3C"
        )
        |> Giggly.to_svg(width: 480, height: 360)
        |> IO.iodata_to_binary()

      assert [_group] = Regex.scan(~r/<g transform='translate\([\d.]+,[\d.]+\)'>\n<svg x=/, svg)
      assert svg =~ ~s(fill="#1a2b3c")
    end

    test "Giggly draws a boxed label annotated in the data on its box, the label after it" do
      svg =
        %{"x" => [1, 2, 3], "y" => [2.0, 4.0, 3.0]}
        |> Giggly.Plot.new(%{x: :x, y: :y})
        |> Giggly.Plot.geom_point()
        |> Giggly.Plot.annotate(:label,
          x: 2,
          y: 3,
          label: GigTypst.math("x_i^2"),
          fill: "#FFEEDD"
        )
        |> Giggly.to_svg(width: 480, height: 360)
        |> IO.iodata_to_binary()

      assert svg =~ ~r/<polygon [^>]*fill: #FFEEDD;[^>]*\/>\n<g transform='translate/
    end

    test "Giggly draws a scale's labels from label_math/2, one formula a break, on an axis and a legend" do
      svg =
        %{"x" => [1, 2, 3], "y" => [2.0, 4.0, 3.0], "g" => ["alpha", "beta", "alpha"]}
        |> Giggly.Plot.new(%{x: :x, y: :y, colour: :g})
        |> Giggly.Plot.geom_point()
        |> Giggly.Plot.scale_x_continuous(
          breaks: [1, 2, 3],
          labels: GigTypst.label_math(fn text -> "x_" <> text end)
        )
        |> Giggly.Plot.scale_color_discrete(labels: GigTypst.label_math(fn text -> text end))
        |> Giggly.to_svg(width: 480, height: 360)
        |> IO.iodata_to_binary()

      assert length(Regex.scan(~r/<g transform='translate\([\d.]+,[\d.]+\)'>\n<svg x=/, svg)) ===
               5
    end
  end
end
