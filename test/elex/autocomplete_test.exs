defmodule Elex.AutocompleteTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog

  defmodule WrapUnit do
    @behaviour Elex.Function

    @impl Elex.Function
    def signature, do: %{name: :wrap_unit, arity: 2, units: :wrap}

    @impl Elex.Function
    def validate(_args, _context), do: {:ok, :decimal}

    @impl Elex.Function
    def call(_args), do: {:ok, Decimal.new(0)}

    @impl Elex.Function
    def documentation do
      %{signature: "wrap_unit(x, unit)", description: "wraps a number in a unit"}
    end
  end

  defmodule SameNameArity1 do
    @behaviour Elex.Function

    @impl Elex.Function
    def signature, do: %{name: :same_name, arity: 1}

    @impl Elex.Function
    def validate(_args, _context), do: {:ok, :decimal}

    @impl Elex.Function
    def call(_args), do: {:ok, Decimal.new(1)}

    @impl Elex.Function
    def documentation do
      %{signature: "same_name(x)", description: "arity-one same_name"}
    end
  end

  defmodule SameNameArity2 do
    @behaviour Elex.Function

    @impl Elex.Function
    def signature, do: %{name: :same_name, arity: 2}

    @impl Elex.Function
    def validate(_args, _context), do: {:ok, :decimal}

    @impl Elex.Function
    def call(_args), do: {:ok, Decimal.new(2)}

    @impl Elex.Function
    def documentation do
      %{signature: "same_name(x, y)", description: "arity-two same_name"}
    end
  end

  setup do
    ctx =
      Elex.new_context()
      |> Elex.add_variable!("foo", 1)
      |> Elex.add_variable!("mass", 2)

    {:ok, ctx: ctx}
  end

  defp with_length_catalog(ctx) do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:length, default: "m")
      |> Catalog.add_unit!(:length, "m", "value")
      |> Catalog.add_unit!(:length, "mm", "value / 1000")

    Context.put_units!(ctx, catalog)
  end

  defp with_energy_catalog(ctx) do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:energy, default: "eV")
      |> Catalog.add_unit!(:energy, "eV", "value")

    Context.put_units!(ctx, catalog)
  end

  defp with_force_catalog(ctx) do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:force, default: "N")
      |> Catalog.add_unit!(:force, "N", "value")

    Context.put_units!(ctx, catalog)
  end

  defp with_area_catalog(ctx) do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:length, default: "m")
      |> Catalog.add_unit!(:length, "m")
      |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
      |> Catalog.add_unit!(:area, "m^2")

    Context.put_units!(ctx, catalog)
  end

  describe "incomplete variable (flow 1)" do
    test "suggests foo for prefix f after an operator", %{ctx: ctx} do
      assert {:ok, %{range: {9, 10}, suggestions: suggestions}} =
               Elex.autocomplete("1 + (2 * f", 10, ctx)

      assert %{kind: :variable, text: "foo"} in suggestions
      assert %{kind: :keyword, text: "false"} in suggestions
      assert Enum.any?(suggestions, &(&1.kind == :function and &1.text == "floor"))
      refute Enum.any?(suggestions, &(&1.kind == :variable and &1.text != "foo"))
    end

    test "returns an empty list when no variable matches the prefix", %{ctx: ctx} do
      assert {:ok, %{suggestions: []}} = Elex.autocomplete("1 + (2 * z", 10, ctx)
    end

    test "suggests foo after and with prefix f", %{ctx: ctx} do
      assert {:ok, %{suggestions: suggestions}} = Elex.autocomplete("true and f", 10, ctx)

      assert %{kind: :variable, text: "foo"} in suggestions
    end

    test "suggests foo after not with prefix f", %{ctx: ctx} do
      assert {:ok, %{suggestions: suggestions}} = Elex.autocomplete("not f", 5, ctx)

      assert %{kind: :variable, text: "foo"} in suggestions
    end

    test "suggests operand names after a two-char equality operator", %{ctx: ctx} do
      assert {:ok, %{range: {5, 6}, suggestions: suggestions}} =
               Elex.autocomplete("1 == f", 6, ctx)

      assert %{kind: :variable, text: "foo"} in suggestions
      assert %{kind: :keyword, text: "false"} in suggestions
      assert Enum.any?(suggestions, &(&1.kind == :function and &1.text == "floor"))
      refute Enum.any?(suggestions, &(&1.kind == :keyword and &1.text in ~w(and or)))
    end
  end

  describe "empty operand (flow 2)" do
    test "returns no suggestions by default after a binary operator", %{ctx: ctx} do
      assert Elex.autocomplete("1 + ", 4, ctx) == {:ok, %{range: {4, 4}, suggestions: []}}
    end

    test "returns no suggestions by default on an empty expression", %{ctx: ctx} do
      assert Elex.autocomplete("", 0, ctx) == {:ok, %{range: {0, 0}, suggestions: []}}
    end
  end

  describe "empty operand opt-in dump (flow 2b)" do
    test "dumps variables, functions, and operand keywords when empty_prefix is :all", %{ctx: ctx} do
      assert {:ok, %{range: {4, 4}, suggestions: suggestions}} =
               Elex.autocomplete("1 + ", 4, ctx, empty_prefix: :all)

      assert %{kind: :variable, text: "foo"} in suggestions
      assert %{kind: :variable, text: "mass"} in suggestions

      assert %{kind: :keyword, text: "true"} in suggestions
      assert %{kind: :keyword, text: "false"} in suggestions
      assert %{kind: :keyword, text: "yes"} in suggestions
      assert %{kind: :keyword, text: "no"} in suggestions
      assert %{kind: :keyword, text: "null"} in suggestions
      assert %{kind: :keyword, text: "not"} in suggestions

      function_infos =
        ctx
        |> Elex.Context.list_functions()
        |> Enum.uniq_by(& &1.name)

      for info <- function_infos do
        suggestion = Enum.find(suggestions, &(&1.text == info.name and &1.kind == :function))
        assert suggestion, "expected function #{info.name}"
        assert suggestion.signature == info.signature
        assert suggestion.description == info.description

        if Map.has_key?(info, :category) do
          assert suggestion.category == info.category
        end
      end

      refute Enum.any?(suggestions, &(&1.kind == :unit))
      refute Enum.any?(suggestions, &(&1.kind == :keyword and &1.text in ~w(and or)))
    end
  end

  describe "infix after a number (flow 4)" do
    test "returns no suggestions by default after a number and space", %{ctx: ctx} do
      assert Elex.autocomplete("10 ", 3, ctx) == {:ok, %{range: {3, 3}, suggestions: []}}
    end

    test "returns only and and or after a number and space when empty_prefix is :all", %{ctx: ctx} do
      assert Elex.autocomplete("10 ", 3, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {3, 3},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end

    test "returns no suggestions on a glued number when empty_prefix is :all", %{ctx: ctx} do
      assert Elex.autocomplete("10", 2, ctx, empty_prefix: :all) ==
               {:ok, %{range: {2, 2}, suggestions: []}}
    end
  end

  describe "glued unit suffix (flow 3)" do
    test "suggests catalog units matching the glued suffix and excludes variables", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{range: {2, 3}, suggestions: suggestions}} = Elex.autocomplete("10m", 3, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
      refute Enum.any?(suggestions, &(&1.text == "mass"))
    end

    test "suggests catalog aliases as well as canonical names", %{ctx: ctx} do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value", aliases: ["metre"])
        |> Catalog.add_unit!(:length, "mm", "value / 1000")

      ctx = Context.put_units!(ctx, catalog)

      assert {:ok, %{suggestions: suggestions}} = Elex.autocomplete("10m", 3, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
      assert %{kind: :unit, text: "metre"} in suggestions
    end

    test "suggests a degree-sign unit glued to a number", %{ctx: ctx} do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:temperature, default: "°C", additive: false)
        |> Catalog.add_unit!(:temperature, "°C")
        |> Catalog.add_unit!(:temperature, "°F", "(value - 32) * 5 / 9")

      ctx = Context.put_units!(ctx, catalog)
      cursor = byte_size("32°")

      assert {:ok, %{range: {2, ^cursor}, suggestions: suggestions}} =
               Elex.autocomplete("32°", cursor, ctx)

      assert %{kind: :unit, text: "°C"} in suggestions
      assert %{kind: :unit, text: "°F"} in suggestions
    end

    test "suggests an uppercase catalog unit glued to a number", %{ctx: ctx} do
      ctx = with_force_catalog(ctx)

      assert {:ok, %{range: {2, 3}, suggestions: suggestions}} = Elex.autocomplete("10N", 3, ctx)

      assert %{kind: :unit, text: "N"} in suggestions
    end

    test "suggests a registered power unit after a typed caret", %{ctx: ctx} do
      ctx = with_area_catalog(ctx)

      assert {:ok, %{range: {2, 4}, suggestions: suggestions}} = Elex.autocomplete("10m^", 4, ctx)

      assert %{kind: :unit, text: "m^2"} in suggestions
    end

    test "treats a scientific number as complete and completes the unit suffix", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{range: {3, 4}, suggestions: suggestions}} = Elex.autocomplete("1e3m", 4, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
    end

    test "treats a complete decimal as a number and completes the glued unit suffix", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{range: {4, 5}, suggestions: suggestions}} =
               Elex.autocomplete("10.5m", 5, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
    end

    test "suggests eV after 10e as a unit prefix not a scientific exponent", %{ctx: ctx} do
      ctx = with_energy_catalog(ctx)

      assert {:ok, %{range: {2, 3}, suggestions: suggestions}} = Elex.autocomplete("10e", 3, ctx)

      assert %{kind: :unit, text: "eV"} in suggestions
    end

    test "suggests eV after 10eV with range starting after 10", %{ctx: ctx} do
      ctx = with_energy_catalog(ctx)

      assert {:ok, %{range: {2, 4}, suggestions: suggestions}} = Elex.autocomplete("10eV", 4, ctx)

      assert %{kind: :unit, text: "eV"} in suggestions
    end
  end

  describe "incomplete numbers (slot :none)" do
    test "returns no suggestions for 10. even when empty_prefix is :all", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{suggestions: []}} =
               Elex.autocomplete("10.", 3, ctx, empty_prefix: :all)
    end

    test "returns no suggestions for 10e+ even when empty_prefix is :all", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{suggestions: []}} =
               Elex.autocomplete("10e+", 4, ctx, empty_prefix: :all)
    end
  end

  describe "incomplete operators (slot :none)" do
    test "returns no suggestions for incomplete = even when empty_prefix is :all", %{ctx: ctx} do
      assert {:ok, %{suggestions: []}} =
               Elex.autocomplete("1 =", 3, ctx, empty_prefix: :all)
    end
  end

  describe "units after a number (flow 4)" do
    test "returns no suggestions by default after a number and space with a catalog", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert Elex.autocomplete("10 ", 3, ctx) == {:ok, %{range: {3, 3}, suggestions: []}}
    end

    test "dumps units and infix keywords after a number and space when empty_prefix is :all", %{
      ctx: ctx
    } do
      ctx = with_length_catalog(ctx)

      assert Elex.autocomplete("10 ", 3, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {3, 3},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :unit, text: "m"},
                    %{kind: :unit, text: "mm"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end

    test "dumps units and infix keywords after a complete decimal and space", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert Elex.autocomplete("10.5 ", 5, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {5, 5},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :unit, text: "m"},
                    %{kind: :unit, text: "mm"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end

    test "dumps units and infix keywords after a signed exponent and space", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert Elex.autocomplete("1e+3 ", 5, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {5, 5},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :unit, text: "m"},
                    %{kind: :unit, text: "mm"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end

    test "dumps only units on a glued number when empty_prefix is :all", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{range: {2, 2}, suggestions: suggestions}} =
               Elex.autocomplete("10", 2, ctx, empty_prefix: :all)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
      refute Enum.any?(suggestions, &(&1.kind == :keyword and &1.text in ~w(and or)))
    end
  end

  describe "infix after a completed quantity" do
    test "returns only and and or after an uppercase unit when empty_prefix is :all", %{ctx: ctx} do
      ctx = with_force_catalog(ctx)

      assert Elex.autocomplete("10N ", 4, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {4, 4},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end

    test "returns only and and or after a power unit when empty_prefix is :all", %{ctx: ctx} do
      ctx = with_area_catalog(ctx)

      assert Elex.autocomplete("10m^2 ", 6, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {6, 6},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end

    test "returns only and and or after a lowercase unit when empty_prefix is :all", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert Elex.autocomplete("10m ", 4, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {4, 4},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end
  end

  describe "infix after a finished call" do
    test "returns only and and or after a finished call when empty_prefix is :all", %{ctx: ctx} do
      assert Elex.autocomplete("foo() ", 6, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {6, 6},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end
  end

  describe "infix after a closed string" do
    test "returns only and and or after a closed string when empty_prefix is :all", %{ctx: ctx} do
      assert Elex.autocomplete("\"hel\" ", 6, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {6, 6},
                  suggestions: [
                    %{kind: :keyword, text: "and"},
                    %{kind: :keyword, text: "or"}
                  ]
                }}
    end

    test "returns no suggestions glued to a closed string when empty_prefix is :all", %{ctx: ctx} do
      assert Elex.autocomplete("\"hel\"", 5, ctx, empty_prefix: :all) ==
               {:ok, %{range: {5, 5}, suggestions: []}}
    end
  end

  describe "unit string argument (flow 8)" do
    test "suggests units matching the prefix inside convert's second argument string", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{range: {13, 14}, suggestions: suggestions}} =
               Elex.autocomplete("convert(1m, \"m", 14, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
    end

    test "returns no suggestions in convert's first argument string", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{suggestions: []}} = Elex.autocomplete("convert(\"m", 10, ctx)
    end

    test "suggests an uppercase catalog unit inside convert's second argument string", %{ctx: ctx} do
      ctx = with_force_catalog(ctx)

      assert {:ok, %{range: {13, 14}, suggestions: suggestions}} =
               Elex.autocomplete("convert(1m, \"N", 14, ctx)

      assert %{kind: :unit, text: "N"} in suggestions
    end

    test "suggests units inside add_unit's second argument string", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{range: {13, 14}, suggestions: suggestions}} =
               Elex.autocomplete("add_unit(1, \"m", 14, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
    end

    test "suggests units inside a custom wrap function's second argument string", %{ctx: ctx} do
      ctx =
        ctx
        |> with_length_catalog()
        |> Context.add_function(WrapUnit)

      assert {:ok, %{range: {14, 15}, suggestions: suggestions}} =
               Elex.autocomplete("wrap_unit(1, \"m", 15, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
    end

    test "returns no suggestions in an empty convert string by default", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert Elex.autocomplete("convert(1m, \"", 13, ctx) ==
               {:ok, %{range: {13, 13}, suggestions: []}}
    end

    test "dumps all unit names and aliases in an empty convert string when empty_prefix is :all",
         %{ctx: ctx} do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value", aliases: ["metre"])
        |> Catalog.add_unit!(:length, "mm", "value / 1000")

      ctx = Context.put_units!(ctx, catalog)

      assert {:ok, %{range: {13, 13}, suggestions: suggestions}} =
               Elex.autocomplete("convert(1m, \"", 13, ctx, empty_prefix: :all)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
      assert %{kind: :unit, text: "metre"} in suggestions
    end

    test "suggests units in convert's second argument after a nested finished call", %{ctx: ctx} do
      ctx = with_length_catalog(ctx)

      assert {:ok, %{range: {20, 21}, suggestions: suggestions}} =
               Elex.autocomplete("convert(max(1, 2), \"m", 21, ctx)

      assert %{kind: :unit, text: "m"} in suggestions
      assert %{kind: :unit, text: "mm"} in suggestions
    end

    test "dumps units in a non-empty unclosed convert string when empty_prefix is :all", %{
      ctx: ctx
    } do
      ctx = with_length_catalog(ctx)

      assert Elex.autocomplete("convert(1m, \"mm ", 16, ctx, empty_prefix: :all) ==
               {:ok,
                %{
                  range: {16, 16},
                  suggestions: [
                    %{kind: :unit, text: "m"},
                    %{kind: :unit, text: "mm"}
                  ]
                }}
    end
  end

  describe "normal string (flow 10)" do
    test "returns no suggestions inside a non-unit string argument", %{ctx: ctx} do
      assert {:ok, %{suggestions: []}} = Elex.autocomplete("concat(\"hel", 11, ctx)
    end

    test "suggests operands after a closed string and operator", %{ctx: ctx} do
      assert {:ok, %{suggestions: suggestions}} =
               Elex.autocomplete("concat(\"hel\") + f", 17, ctx)

      assert %{kind: :variable, text: "foo"} in suggestions
      assert %{kind: :keyword, text: "false"} in suggestions
      assert Enum.any?(suggestions, &(&1.kind == :function and &1.text == "floor"))
    end

    test "returns no suggestions when an escaped quote keeps the string open", %{ctx: ctx} do
      assert {:ok, %{suggestions: []}} = Elex.autocomplete("concat(\"hel\\\"", 13, ctx)
    end
  end

  describe "no catalog (flow 11)" do
    test "returns no suggestions for a glued unit suffix when units is nil", %{ctx: ctx} do
      assert Elex.autocomplete("10m", 3, ctx) == {:ok, %{range: {2, 3}, suggestions: []}}
    end
  end

  describe "function name (flow 5)" do
    test "suggests max, match, and mass for prefix ma after an operator", %{ctx: ctx} do
      assert {:ok, %{range: {4, 6}, suggestions: suggestions}} =
               Elex.autocomplete("1 + ma", 6, ctx)

      max = Enum.find(suggestions, &(&1.text == "max"))
      match = Enum.find(suggestions, &(&1.text == "match"))

      assert %{kind: :function, text: "max", signature: signature, description: description} = max
      assert signature == "max(a, b, ...)"
      assert description == "returns the largest of the given values"
      assert max.category == :math
      refute String.contains?(max.text, "(")

      assert %{kind: :function, text: "match", signature: match_sig, description: match_desc} =
               match

      assert match_sig == "match(text, pattern)"
      assert match_desc == "returns true when text matches the regex pattern"
      refute String.contains?(match.text, "(")

      assert %{kind: :variable, text: "mass"} in suggestions
    end

    test "keeps one suggestion per name when multiple arities are registered", %{ctx: ctx} do
      ctx =
        ctx
        |> Context.add_function(SameNameArity2)
        |> Context.add_function(SameNameArity1)

      expected =
        ctx
        |> Context.list_functions()
        |> Enum.find(&(&1.name == "same_name"))

      assert expected

      assert {:ok, %{suggestions: suggestions}} =
               Elex.autocomplete("1 + same_na", 11, ctx)

      same_name_suggestions =
        Enum.filter(suggestions, &(&1.kind == :function and &1.text == "same_name"))

      assert length(same_name_suggestions) == 1
      [suggestion] = same_name_suggestions
      assert suggestion.signature == expected.signature
      assert suggestion.description == expected.description
    end
  end

  describe "operand keywords (flow 6)" do
    test "suggests not, null, and no for prefix n", %{ctx: ctx} do
      assert {:ok, %{range: {0, 1}, suggestions: suggestions}} = Elex.autocomplete("n", 1, ctx)

      assert %{kind: :keyword, text: "not"} in suggestions
      assert %{kind: :keyword, text: "null"} in suggestions
      assert %{kind: :keyword, text: "no"} in suggestions
    end
  end

  describe "infix keywords (flow 7)" do
    test "suggests and after a complete identifier and excludes functions", %{ctx: ctx} do
      assert {:ok, %{range: {5, 6}, suggestions: suggestions}} =
               Elex.autocomplete("true a", 6, ctx)

      assert %{kind: :keyword, text: "and"} in suggestions
      refute Enum.any?(suggestions, &(&1.text == "abs"))
    end
  end

  describe "cursor in the middle of a token (flow 9)" do
    test "replaces the whole identifier and matches the prefix before the cursor", %{ctx: ctx} do
      assert {:ok, %{range: {4, 10}, suggestions: suggestions}} =
               Elex.autocomplete("1 + foobar", 6, ctx)

      assert %{kind: :variable, text: "foo"} in suggestions
    end

    test "stops the replacement range at the identifier end before EOF", %{ctx: ctx} do
      assert {:ok, %{range: {4, 10}, suggestions: suggestions}} =
               Elex.autocomplete("1 + foobar + 1", 6, ctx)

      assert %{kind: :variable, text: "foo"} in suggestions
    end
  end

  describe "invalid cursor (flow 12)" do
    test "rejects a cursor past the end of the expression", %{ctx: ctx} do
      assert Elex.autocomplete("1 + 2", 99, ctx) == {:error, "cursor is out of range"}
    end

    test "rejects a negative cursor", %{ctx: ctx} do
      assert Elex.autocomplete("1 + 2", -1, ctx) == {:error, "cursor is out of range"}
    end

    test "rejects a cursor in the middle of a UTF-8 codepoint", %{ctx: ctx} do
      assert Elex.autocomplete("é", 1, ctx) == {:error, "cursor is out of range"}
    end

    test "rejects a non-integer cursor", %{ctx: ctx} do
      assert Elex.autocomplete("1+2", :x, ctx) == {:error, "cursor is out of range"}
    end
  end

  describe "options" do
    test "raises ArgumentError on an unknown option", %{ctx: ctx} do
      assert_raise ArgumentError, "unknown option :bogus", fn ->
        Elex.autocomplete("1", 1, ctx, bogus: true)
      end
    end

    test "raises ArgumentError naming empty_prefix when the value is invalid", %{ctx: ctx} do
      assert_raise ArgumentError, ~r/empty_prefix/, fn ->
        Elex.autocomplete("1", 1, ctx, empty_prefix: :bogus)
      end
    end
  end
end
