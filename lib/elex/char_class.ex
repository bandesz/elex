defmodule Elex.CharClass do
  @moduledoc false

  @ident_start [?a..?z]
  @ident_continue [?a..?z, ?0..?9, ?_]
  @unit_start [?A..?Z, ?a..?z]
  @unit_continue [?A..?Z, ?a..?z, ?0..?9, ?_]
  @digit [?0..?9]
  @whitespace [?\s, ?\t]

  def ident_start_chars, do: @ident_start
  def ident_continue_chars, do: @ident_continue
  def unit_start_chars, do: @unit_start
  def unit_continue_chars, do: @unit_continue
  def digit_chars, do: @digit
  def whitespace_chars, do: @whitespace

  def ident_start?(byte) when is_integer(byte), do: byte_in?(@ident_start, byte)
  def ident_continue?(byte) when is_integer(byte), do: byte_in?(@ident_continue, byte)
  def unit_start?(byte) when is_integer(byte), do: byte_in?(@unit_start, byte)
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
