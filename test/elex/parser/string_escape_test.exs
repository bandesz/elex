defmodule Elex.Parser.StringEscapeTest do
  use ExUnit.Case, async: true

  alias Elex.Parser.StringEscape

  describe "decode/1" do
    test "decodes standard escape sequences" do
      assert StringEscape.decode(?") == {:ok, "\""}
      assert StringEscape.decode(?\\) == {:ok, "\\"}
      assert StringEscape.decode(?n) == {:ok, "\n"}
      assert StringEscape.decode(?t) == {:ok, "\t"}
      assert StringEscape.decode(?r) == {:ok, "\r"}
      assert StringEscape.decode(?f) == {:ok, "\f"}
      assert StringEscape.decode(?b) == {:ok, "\b"}
    end

    test "rejects unknown escape sequences" do
      assert {:error, "invalid escape sequence '\\d'"} = StringEscape.decode(?d)
      assert {:error, "invalid escape sequence '\\z'"} = StringEscape.decode(?z)
    end
  end

  describe "skip_binary/1" do
    test "skips a two-character escape sequence" do
      assert StringEscape.skip_binary("\\nrest") == "rest"
      assert StringEscape.skip_binary("\\\"rest") == "rest"
    end

    test "returns nil when the escape is incomplete" do
      assert StringEscape.skip_binary("\\") == nil
    end
  end

  describe "skip_charlist/1" do
    test "skips a two-character escape sequence" do
      assert StringEscape.skip_charlist([?\\, ?n, ?r, ?e, ?s, ?t]) == [?r, ?e, ?s, ?t]
    end

    test "returns nil when the escape is incomplete" do
      assert StringEscape.skip_charlist([?\\]) == nil
    end
  end

  describe "escapes/0" do
    test "lists every supported escape character" do
      chars = Map.keys(StringEscape.escapes()) |> Enum.sort()
      assert length(chars) == 7
      assert ?n in chars
      assert ?\\ in chars
    end
  end
end
