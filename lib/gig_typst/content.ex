defmodule GigTypst.Content do
  @moduledoc """
  A label Typst lays out, as `GigTypst.text/2` and `GigTypst.math/2` make it: its source, how it
  is read (`:markup`, `:inline_math` or `:display_math`), the font directories it looks in and
  its maths font. It implements `Giggly.Label`, so it goes where a title's string goes.
  """

  @enforce_keys [:source, :mode, :font_dirs, :math_family]
  defstruct @enforce_keys

  @type mode :: :markup | :inline_math | :display_math

  @type t :: %__MODULE__{
          source: String.t(),
          mode: mode(),
          font_dirs: [Path.t()],
          math_family: String.t()
        }

  @default_math_family "New Computer Modern Math"

  # A content of `source` read in `mode`, its options checked: `:font_dirs` and `:math_family`.
  @doc false
  @spec new(String.t(), mode(), keyword()) :: t()
  def new(source, mode, options) do
    options = Keyword.validate!(options, font_dirs: [], math_family: @default_math_family)
    font_dirs = Keyword.fetch!(options, :font_dirs)
    math_family = Keyword.fetch!(options, :math_family)

    unless is_list(font_dirs) and Enum.all?(font_dirs, &is_binary/1),
      do:
        raise(
          ArgumentError,
          "expected :font_dirs to be a list of paths, got: #{inspect(font_dirs)}"
        )

    unless is_binary(math_family),
      do:
        raise(ArgumentError, "expected :math_family to be a string, got: #{inspect(math_family)}")

    %__MODULE__{source: source, mode: mode, font_dirs: font_dirs, math_family: math_family}
  end

  defimpl Giggly.Label do
    alias Giggly.Label.Style
    alias GigTypst.Document

    def layout(content, %Style{} = style), do: Document.layout(content, style)
  end
end
