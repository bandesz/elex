defmodule Elex.Units.ParserTest do
  use ExUnit.Case, async: true

  alias Elex.{Context, Parser, Unit}
  alias Elex.Units.Catalog

  describe "parse/3 unit suffix with catalog" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "h", "value * 3600")
      {:ok, catalog} = Catalog.add_category(catalog, :force, default: "N")
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "extract_variables reads unit suffixes when a catalog is attached", %{ctx: ctx} do
      assert Elex.extract_variables("width + 2mm", ctx) == {:ok, ["width"]}
    end

    test "parses a number with an adjacent unit symbol", %{ctx: ctx} do
      assert Parser.parse("10mm", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("10"), "mm"}, nil}
    end

    test "parses a number with a unit symbol after whitespace", %{ctx: ctx} do
      assert Parser.parse("10 mm", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("10"), "mm"}, nil}
    end

    test "matches unit symbols case-sensitively", %{ctx: ctx} do
      assert Parser.parse("10mm", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("10"), "mm"}, nil}

      refute Parser.parse("10MM", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("10"), "mm"}, nil}
    end

    test "parses an uppercase unit symbol when it is registered", %{ctx: ctx} do
      assert Parser.parse("10N", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("10"), "N"}, nil}
    end

    test "does not consume operators after a number", %{ctx: ctx} do
      assert Parser.parse("10 + 1", ctx, validate: false) ==
               {:ok, {:+, [Decimal.new("10"), Decimal.new("1")]}, nil}
    end

    test "does not consume 'and' after a number", %{ctx: ctx} do
      assert Parser.parse("10 and true", ctx, validate: false) ==
               {:ok, {:and, [Decimal.new("10"), true]}, nil}
    end

    test "parses scientific notation as a number", %{ctx: ctx} do
      assert Parser.parse("1e3", ctx, validate: false) ==
               {:ok, Decimal.new("1e3"), nil}

      assert Parser.parse("1.5E-2", ctx, validate: false) ==
               {:ok, Decimal.new("1.5E-2"), nil}

      assert Parser.parse("2e+3", ctx, validate: false) ==
               {:ok, Decimal.new("2e+3"), nil}
    end

    test "attaches a unit suffix after scientific notation", %{ctx: ctx} do
      assert Parser.parse("1e3mm", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("1e3"), "mm"}, nil}

      assert Parser.parse("1e3 mm", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("1e3"), "mm"}, nil}
    end

    test "does not treat eV as scientific notation", %{ctx: ctx} do
      {:ok, catalog} = Catalog.add_unit(ctx.units, :length, "eV", "value")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert Parser.parse("10eV", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("10"), "eV"}, nil}
    end

    test "rejects an unregistered unit symbol", %{ctx: ctx} do
      assert Parser.parse("1foo", ctx, validate: false) ==
               {:error, "unknown unit 'foo'"}
    end

    test "rejects an unregistered unit symbol after whitespace", %{ctx: ctx} do
      assert Parser.parse("1 foo", ctx, validate: false) ==
               {:error, "unknown unit 'foo'"}
    end

    test "rejects an unregistered unit symbol after an operator", %{ctx: ctx} do
      assert Parser.parse("1m / 1foo", ctx, validate: false) ==
               {:error, "unknown unit 'foo'"}
    end

    test "does not attach a unit suffix to a variable", %{ctx: ctx} do
      assert Parser.parse("width mm", ctx, validate: false) ==
               {:error, "unexpected 'mm'"}
    end

    test "does not treat a reserved keyword after a number as a unit suffix", %{ctx: ctx} do
      assert Parser.parse("10 true", ctx, validate: false) ==
               {:error, "unexpected 'true'"}
    end

    test "rejects m2 when it is not a registered name or alias", %{ctx: ctx} do
      assert Parser.parse("5 m2", ctx, validate: false) ==
               {:error, "unknown unit 'm2'"}
    end

    test "does not treat spaces around ^ as a power suffix", %{ctx: ctx} do
      assert Parser.parse("5m ^ 2", ctx, validate: false) ==
               {:error, "spaces around '^' are not a power suffix; write 5m^2"}
    end

    test "parses a power suffix when the prefix unit is registered", %{ctx: ctx} do
      assert Parser.parse("5 mm^3", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("5"), "mm^3"}, nil}
    end

    test "parses glued /s as division by a variable, not a unit suffix", %{ctx: ctx} do
      assert Parser.parse("10m/s", ctx, validate: false) ==
               {:ok, {:/, [{:unit, Decimal.new("10"), "m"}, {:var, "s"}]}, nil}

      assert Elex.evaluate("10m/s", ctx) == {:error, "variable 's' does not exist"}
    end

    test "rejects a formula bar when the denominator is unknown", %{ctx: ctx} do
      assert Parser.parse("10m | foo", ctx, validate: false) == {:error, "unknown unit 'foo'"}
    end

    test "rejects a negative exponent as a power suffix", %{ctx: ctx} do
      assert Parser.parse("5m^-1", ctx, validate: false) ==
               {:error, "negative exponents belong in braces, for example 1 {s^-2}"}

      assert Parser.parse("1s^-2", ctx, validate: false) ==
               {:error, "negative exponents belong in braces, for example 1 {s^-2}"}
    end

    test "rejects a zero or leading-zero exponent as an invalid formula", %{ctx: ctx} do
      assert Parser.parse("5m^0", ctx, validate: false) == {:error, "invalid formula 'm^0'"}
      assert Parser.parse("5m^01", ctx, validate: false) == {:error, "invalid formula 'm^01'"}
    end
  end

  describe "parse/3 aliases and registered power names" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_unit!(:length, "cm", "value / 100")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2", "value", aliases: ["m2", "sqm"])
        |> Catalog.add_unit!(:area, "cm^2", "value / 10000", aliases: ["cm2"])

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "parses an alias after a number", %{ctx: ctx} do
      assert Parser.parse("5 m2", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("5"), "m2"}, nil}
    end

    test "parses a glued power suffix", %{ctx: ctx} do
      assert Parser.parse("5m^2", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("5"), "m^2"}, nil}
    end

    test "parses a power suffix after whitespace", %{ctx: ctx} do
      assert Parser.parse("5 m^2", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("5"), "m^2"}, nil}
    end

    test "parses a sqm alias", %{ctx: ctx} do
      assert Parser.parse("5 sqm", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("5"), "sqm"}, nil}
    end

    test "parses a cm2 alias", %{ctx: ctx} do
      assert Parser.parse("5 cm2", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("5"), "cm2"}, nil}
    end
  end

  describe "parse/3 without catalog" do
    setup do
      %{ctx: Elex.new_context()}
    end

    test "parses scientific notation when units is nil", %{ctx: ctx} do
      assert Parser.parse("1e3", ctx, validate: false) ==
               {:ok, Decimal.new("1e3"), nil}
    end

    test "parses unitless arithmetic when units is nil", %{ctx: ctx} do
      assert Parser.parse("10 + 1", ctx, validate: false) ==
               {:ok, {:+, [Decimal.new("10"), Decimal.new("1")]}, nil}
    end

    test "parses 'and' after a number when units is nil", %{ctx: ctx} do
      assert Parser.parse("10 and true", ctx, validate: false) ==
               {:ok, {:and, [Decimal.new("10"), true]}, nil}
    end

    test "rejects a glued unit-like token when units is nil", %{ctx: ctx} do
      assert Parser.parse("1cm", ctx, validate: false) ==
               {:error, "unexpected 'cm'"}
    end

    test "rejects a spaced unit-like token when units is nil", %{ctx: ctx} do
      assert Parser.parse("1 cm", ctx, validate: false) ==
               {:error, "unexpected 'cm'"}
    end

    test "rejects a unit-like token after addition when units is nil", %{ctx: ctx} do
      assert Parser.parse("width + 2mm", ctx, validate: false) ==
               {:error, "unexpected 'mm'"}
    end

    test "rejects an unbraced pipe suffix when units is nil", %{ctx: ctx} do
      assert Parser.parse("3 m|s", ctx, validate: false) ==
               {:error, "unexpected 'm'"}
    end

    test "rejects a braced formula suffix when units is nil", %{ctx: ctx} do
      assert Parser.parse("1 {m | s}", ctx, validate: false) ==
               {:error, "unexpected '{'"}
    end
  end

  describe "parse/3 unbraced pipe suffixes" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_unit!(:length, "mm", "value / 1000")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")
        |> Catalog.add_unit!(:time, "h", "value * 3600")
        |> Catalog.add_category!(:mass, default: "kg")
        |> Catalog.add_unit!(:mass, "kg", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "parses glued and spaced pipe suffixes", %{ctx: ctx} do
      assert Parser.parse("3 m|s", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("3"), "m|s"}, nil}

      assert Parser.parse("3m|s", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("3"), "m|s"}, nil}

      assert Parser.parse("3 m | s", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("3"), "m | s"}, nil}
    end

    test "parses a pipe suffix with a power on the denominator", %{ctx: ctx} do
      assert Parser.parse("3 m|s^2", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("3"), "m|s^2"}, nil}
    end

    test "parses a product of a named unit and a pipe suffix", %{ctx: ctx} do
      assert Parser.parse("1kg * 1m|s", ctx, validate: false) ==
               {:ok, {:*, [{:unit, Decimal.new("1"), "kg"}, {:unit, Decimal.new("1"), "m|s"}]},
                nil}
    end

    test "binds a trailing * 2 to the pipe-suffixed quantity", %{ctx: ctx} do
      assert Parser.parse("3 m | s * 2", ctx, validate: false) ==
               {:ok, {:*, [{:unit, Decimal.new("3"), "m | s"}, Decimal.new("2")]}, nil}
    end

    test "rejects repeating the unbraced denominator with *", %{ctx: ctx} do
      assert Parser.parse("3 m | s * s", ctx, validate: false) ==
               {:error,
                "unbraced pipe suffixes cannot continue with '* s'; write a power on the denominator or a braced formula"}

      assert Parser.parse("3m|s*s", ctx, validate: false) ==
               {:error,
                "unbraced pipe suffixes cannot continue with '* s'; write a power on the denominator or a braced formula"}
    end

    test "rejects continuing an unbraced pipe with a registered unit", %{ctx: ctx} do
      assert Parser.parse("3 m | s * h", ctx, validate: false) ==
               {:error,
                "unbraced pipe suffixes cannot continue with '* h'; write a power on the denominator or a braced formula"}
    end

    test "parses 10m / 1s as expression division, not a pipe suffix", %{ctx: ctx} do
      assert Parser.parse("10m / 1s", ctx, validate: false) ==
               {:ok, {:/, [{:unit, Decimal.new("10"), "m"}, {:unit, Decimal.new("1"), "s"}]}, nil}
    end

    test "does not treat spaces around ^ as a power suffix", %{ctx: ctx} do
      assert Parser.parse("5m ^ 2", ctx, validate: false) ==
               {:error, "spaces around '^' are not a power suffix; write 5m^2"}
    end

    test "rejects a pipe suffix when the denominator is unknown", %{ctx: ctx} do
      assert Parser.parse("3 m|foo", ctx, validate: false) ==
               {:error, "unknown unit 'foo'"}
    end

    test "rejects a pipe suffix that repeats a category", %{ctx: ctx} do
      assert Parser.parse("1 m|m", ctx, validate: false) ==
               {:error, "invalid formula 'm|m'"}

      assert Parser.parse("1 m|mm", ctx, validate: false) ==
               {:error,
                "formula 'm|mm' repeats category :length in the numerator and denominator"}
    end

    test "evaluates pipe suffixes to an m | s monomial", %{ctx: ctx} do
      for expr <- ["3 m|s", "3m|s", "3 m | s"] do
        assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate(expr, ctx)
        assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
        assert Decimal.compare(value, Decimal.new("3")) == :eq
        assert inspect(qty) == "#Elex.Quantity<3 m | s>"
      end
    end

    test "evaluates a pipe suffix with a squared denominator", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("3 m|s^2", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("3")) == :eq
      assert inspect(qty) == "#Elex.Quantity<3 m | s^2>"
    end

    test "evaluates 1kg * 1m|s as kg * m | s", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1kg * 1m|s", ctx)

      assert %Unit{monomial: %{"kg" => 1, "m" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
      assert inspect(qty) == "#Elex.Quantity<1 kg * m | s>"
    end

    test "evaluates 3 m | s * 2 as six metres per second", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("3 m | s * 2", ctx)
      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("6")) == :eq
    end

    test "evaluates 10m / 1s as metres per second", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("10m / 1s", ctx)
      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end

    test "validates a pipe suffix as length | time", %{ctx: ctx} do
      assert Elex.validate("3 m|s", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, time: -1}}}
    end
  end

  describe "parse/3 braced formula suffixes" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_unit!(:length, "mm", "value / 1000")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")
        |> Catalog.add_category!(:mass, default: "kg")
        |> Catalog.add_unit!(:mass, "kg", "value")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2")
        |> Catalog.add_unit!(:area, "ha", "value * 10000")
        |> Catalog.add_category!(:force,
          formula: "mass * length | time^2",
          default: "N",
          identity: "kg * m | s^2"
        )
        |> Catalog.add_unit!(:force, "N")
        |> Catalog.add_unit!(:force, "kg * m | s^2")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "parses glued and spaced braced formula suffixes", %{ctx: ctx} do
      assert Parser.parse("1 {kg * m | s}", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("1"), "kg * m | s"}, nil}

      assert Parser.parse("1{kg * m | s}", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("1"), "kg * m | s"}, nil}
    end

    test "parses a braced pipe that matches an unbraced pipe suffix", %{ctx: ctx} do
      assert Parser.parse("1 {m | s}", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("1"), "m | s"}, nil}

      assert Parser.parse("1 m|s", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("1"), "m|s"}, nil}
    end

    test "parses a braced negative exponent", %{ctx: ctx} do
      assert Parser.parse("1 {s^-1}", ctx, validate: false) ==
               {:ok, {:unit, Decimal.new("1"), "s^-1"}, nil}
    end

    test "evaluates braced formulas to a kg * m | s monomial", %{ctx: ctx} do
      for expr <- ["1 {kg * m | s}", "1{kg * m | s}"] do
        assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate(expr, ctx)
        assert %Unit{monomial: %{"kg" => 1, "m" => 1, "s" => -1}} = unit
        assert Decimal.compare(value, Decimal.new("1")) == :eq
        assert inspect(qty) == "#Elex.Quantity<1 kg * m | s>"
      end
    end

    test "evaluates a braced pipe as the same unit as an unbraced pipe", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: braced}} = Elex.evaluate("1 {m | s}", ctx)
      assert {:ok, %Elex.Quantity{unit: unbraced}} = Elex.evaluate("1 m|s", ctx)
      assert Unit.same?(braced, unbraced)
    end

    test "evaluates a braced inverse as 1 | s", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1 {s^-1}", ctx)

      assert %Unit{monomial: %{"s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
      assert inspect(qty) == "#Elex.Quantity<1 | s>"
    end

    test "treats a braced formula as the same unit as factor arithmetic", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: braced}} = Elex.evaluate("1 {kg * m | s}", ctx)
      assert {:ok, %Elex.Quantity{unit: arithmetic}} = Elex.evaluate("1kg * 1m|s", ctx)
      assert Unit.same?(braced, arithmetic)
    end

    test "rejects an unbraced product with a trailing pipe", %{ctx: ctx} do
      assert Parser.parse("1 kg * m | s", ctx, validate: false) ==
               {:error,
                "unexpected '|'; compound units belong in braces, for example 1 {kg * m | s}"}
    end

    test "rejects a braced formula with an unknown component", %{ctx: ctx} do
      assert Parser.parse("1 {kg * foo | s}", ctx, validate: false) ==
               {:error, "unknown unit 'foo'"}
    end

    test "rejects a slash inside braces as an invalid formula", %{ctx: ctx} do
      assert Parser.parse("1 {m / s}", ctx, validate: false) ==
               {:error, "invalid formula 'm / s'; use '|' for division (m | s, km | h), not '/'"}
    end

    test "rejects empty braces as an invalid formula", %{ctx: ctx} do
      assert Parser.parse("1 {}", ctx, validate: false) == {:error, "invalid formula ''"}
    end

    test "rejects a braced formula that cancels or repeats a category", %{ctx: ctx} do
      assert Parser.parse("1 {m | m}", ctx, validate: false) ==
               {:error, "invalid formula 'm | m'"}

      assert Parser.parse("1 {m^0}", ctx, validate: false) ==
               {:error, "invalid formula 'm^0'"}

      assert Parser.parse("1 {m^01}", ctx, validate: false) ==
               {:error, "invalid formula 'm^01'"}

      assert Parser.parse("1 {m | mm}", ctx, validate: false) ==
               {:error,
                "formula 'm | mm' repeats category :length in the numerator and denominator"}

      assert Parser.parse("1 {ha | m^2}", ctx, validate: false) ==
               {:error,
                "formula 'ha | m^2' repeats category :length in the numerator and denominator"}

      assert Parser.parse("1 {N * s^2 | kg * m}", ctx, validate: false) ==
               {:error,
                "formula 'N * s^2 | kg * m' repeats category :length in the numerator and denominator"}

      assert {:error, message} = Elex.evaluate("1 {ha | m^2}", ctx)

      assert message ==
               "formula 'ha | m^2' repeats category :length in the numerator and denominator"

      assert {:error, message} = Elex.evaluate("1 {N * s^2 | kg * m}", ctx)

      assert message ==
               "formula 'N * s^2 | kg * m' repeats category :length in the numerator and denominator"
    end

    test "rejects unclosed braces", %{ctx: ctx} do
      assert Parser.parse("1 {kg * m | s", ctx, validate: false) == {:error, "unclosed '{'"}
    end

    test "does not attach a braced suffix to a grouped expression", %{ctx: ctx} do
      assert Parser.parse("(1+2) {m | s}", ctx, validate: false) ==
               {:error, "unexpected '{'"}
    end
  end
end
