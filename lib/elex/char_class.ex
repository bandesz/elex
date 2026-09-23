defmodule Elex.CharClass do
  @moduledoc false

  @ident_start [?a..?z]
  @ident_continue [?a..?z, ?0..?9, ?_]
  @unit_start [?A..?Z, ?a..?z]
  @unit_continue [?A..?Z, ?a..?z, ?0..?9, ?_]
  @digit [?0..?9]
  @whitespace [?\s, ?\t]
  # Codepoints, not NimbleParsec bytes. UTF-8 for ° is <<0xC2, 0xB0>>, not 0xB0.
  # ° U+00B0, µ U+00B5, and μ U+03BC only start a symbol (`°C`, `µm`).
  # Ω U+03A9 and Ω U+2126 may start (`Ω`) or continue (`kΩ`, `µΩ`).
  @degree_sign 0x00B0
  @micro_sign 0x00B5
  @greek_mu 0x03BC
  @ohm 0x03A9
  @ohm_sign 0x2126
  @symbol_starts [@degree_sign, @micro_sign, @greek_mu, @ohm, @ohm_sign]
  @symbol_continues [@ohm, @ohm_sign]

  def ident_start_chars, do: @ident_start
  def ident_continue_chars, do: @ident_continue
  def unit_start_chars, do: @unit_start
  def unit_continue_chars, do: @unit_continue
  def digit_chars, do: @digit
  def whitespace_chars, do: @whitespace

  def ident_start?(byte) when is_integer(byte), do: byte_in?(@ident_start, byte)
  def ident_continue?(byte) when is_integer(byte), do: byte_in?(@ident_continue, byte)
  def unit_start?(byte) when is_integer(byte), do: byte_in?(@unit_start, byte)

  def unit_symbol_start?(codepoint) when is_integer(codepoint) do
    unit_start?(codepoint) or codepoint in @symbol_starts
  end

  def unit_symbol_continue?(codepoint) when is_integer(codepoint) do
    unit_continue?(codepoint) or codepoint in @symbol_continues
  end

  def unit_continue?(byte) when is_integer(byte), do: byte_in?(@unit_continue, byte)
  def digit?(byte) when is_integer(byte), do: byte_in?(@digit, byte)
  def whitespace?(byte) when is_integer(byte), do: byte_in?(@whitespace, byte)

  defp byte_in?(specs, byte) do
    Enum.any?(specs, fn
      %Range{} = range -> byte in range
      code when is_integer(code) -> byte == code
    end)
  end
end
