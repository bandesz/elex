defmodule Elex.Parser.StringEscape do
  @moduledoc false

  @escapes %{
    ?" => "\"",
    ?\\ => "\\",
    ?n => "\n",
    ?t => "\t",
    ?r => "\r",
    ?f => "\f",
    ?b => "\b"
  }

  @doc false
  @spec escapes() :: %{char() => String.t()}
  def escapes, do: @escapes

  @doc false
  @spec decode(char()) :: {:ok, String.t()} | {:error, String.t()}
  def decode(char) when is_integer(char) do
    case Map.fetch(@escapes, char) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, invalid_escape_message(char)}
    end
  end

  @doc false
  @spec skip_binary(String.t()) :: String.t() | nil
  def skip_binary(<<"\\", _char, rest::binary>>), do: rest
  def skip_binary(_), do: nil

  @doc false
  @spec skip_charlist(charlist()) :: charlist() | nil
  def skip_charlist([?\\, _char | rest]), do: rest
  def skip_charlist(_), do: nil

  @doc false
  @spec invalid_escape_message(char()) :: String.t()
  def invalid_escape_message(char) do
    "invalid escape sequence '\\#{<<char::utf8>>}'"
  end
end
