defmodule Elex.Units.DerivedTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Unit
  alias Elex.Units.Catalog

  describe "validate/2 derived expressions" do
    setup do
      %{ctx: context(derived_catalog())}
    end

    test "length * length is length^2 even when :area is registered", %{ctx: ctx} do
      assert {:ok, %Elex.Dimension{monomial: %{length: 2}} = dim} = Elex.validate("1m * 2m", ctx)
      assert inspect(dim) == "#Elex.Dimension<length^2>"
    end

    test "unregistered mm * mm still validates as length^2", %{ctx: ctx} do
      assert Elex.validate("1mm * 1mm", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 2}}}
    end

    test "length / (time * time) is the acceleration formula, not :acceleration", %{ctx: ctx} do
      assert {:ok, dim} = Elex.validate("10mm / (1hour * 1hour)", ctx)
      assert dim == %Elex.Dimension{monomial: %{length: 1, time: -2}}
      assert inspect(dim) == "#Elex.Dimension<length | time^2>"
    end

    test "time * time is valid as time^2 without a registered category", %{ctx: ctx} do
      assert Elex.validate("1hour * 1hour", ctx) == {:ok, %Elex.Dimension{monomial: %{time: 2}}}
    end

    test "length * mass is valid without a registered combination", %{ctx: ctx} do
      assert {:ok, dim} = Elex.validate("1m * 1kg", ctx)
      assert dim == %Elex.Dimension{monomial: %{length: 1, mass: 1}}
      assert inspect(dim) == "#Elex.Dimension<length * mass>"
    end
  end

  describe "validate/3 category option" do
    test "1m * 1m is length^2 without an :area category" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      ctx = context(catalog)

      assert {:ok, dim} = Elex.validate("1m * 1m", ctx)
      assert dim == %Elex.Dimension{monomial: %{length: 2}}
      assert inspect(dim) == "#Elex.Dimension<length^2>"
    end

    test "category: :length on 1m * 1m errors that length was expected" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      ctx = context(catalog)

      assert {:error, message} = Elex.validate("1m * 1m", ctx, category: :length)
      assert message == "length was expected, got length^2"
    end

    test "category: :length on 1m * 1kg names the mixed dimension" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")
      ctx = context(catalog)

      assert {:error, message} = Elex.validate("1m * 1kg", ctx, category: :length)
      assert message == "length was expected, got length * mass"
    end

    test "category: :area on 1m * 1m succeeds and still returns length^2" do
      ctx = context(derived_catalog())

      assert Elex.validate("1m * 1m", ctx, category: :area) ==
               {:ok, %Elex.Dimension{monomial: %{length: 2}}}
    end

    test "category: :speed on 1cm / 1s succeeds and returns length | time" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")
      ctx = context(catalog)

      assert {:ok, dim} = Elex.validate("1cm / 1s", ctx, category: :speed)
      assert dim == %Elex.Dimension{monomial: %{length: 1, time: -1}}
      assert inspect(dim) == "#Elex.Dimension<length | time>"
    end

    test "evaluate category: :speed with unit: mm | s converts the result" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")
      ctx = context(catalog)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m / 1s", ctx, category: :speed, unit: "mm | s")

      assert %Unit{monomial: %{"mm" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "category: :speed on 1m * 1m errors that speed was expected" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")
      ctx = context(catalog)

      assert {:error, message} = Elex.validate("1m * 1m", ctx, category: :speed)
      assert message == "speed was expected, got length^2"
    end

    test "category: :speed on a boolean result errors that speed was expected" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")
      ctx = context(catalog)

      assert {:error, message} = Elex.validate("1m > 1m", ctx, category: :speed)
      assert message == "speed was expected, got yes/no"
    end

    test "category: :acceleration on 1hour * 1hour errors" do
      ctx = context(derived_catalog())

      assert {:error, message} = Elex.validate("1hour * 1hour", ctx, category: :acceleration)
      assert message == "acceleration was expected, got time^2"
    end

    test "category: :acceleration accepts length over time squared" do
      ctx = context(derived_catalog())

      assert Elex.validate("1m / (1s * 1s)", ctx, category: :acceleration) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, time: -2}}}
    end

    test "category: with no catalog raises" do
      ctx = Elex.new_context()

      assert_raise ArgumentError, "category: requires a units catalog", fn ->
        Elex.validate("1 + 1", ctx, category: :length)
      end
    end

    test "unknown category: raises" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      ctx = context(catalog)

      assert_raise ArgumentError, "unknown category :speed", fn ->
        Elex.validate("1m", ctx, category: :speed)
      end
    end
  end

  describe "evaluate/2 derived expressions" do
    setup do
      %{ctx: context(derived_catalog())}
    end

    test "multiplies length into a leftover m * m monomial", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate("1m * 2m", ctx)
      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
      assert inspect(qty) == "#Elex.Quantity<2 m^2>"
    end

    test "keeps unregistered mm * mm as mm squared", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1mm * 1mm", ctx)
      assert %Unit{monomial: %{"mm" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts leftover area into the registered hub when unit: is set", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1mm * 1mm", ctx, unit: "m * m")

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("0.000001")) == :eq
    end

    test "keeps leftover millimetres per hour squared", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("10mm / (1hour * 1hour)", ctx)

      assert %Unit{monomial: %{"mm" => 1, "hour" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("10")) == :eq
      assert inspect(qty) == "#Elex.Quantity<10 mm | hour^2>"
    end

    test "inspects leftover metres per second squared with a caret", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("10m / (1s * 1s)", ctx)
      assert inspect(qty) == "#Elex.Quantity<10 m | s^2>"
    end

    test "rejects unit: m2 when m2 is not registered", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m * 2m", ctx, unit: "m2")
      assert message == "unknown unit 'm2'"
    end

    test "rejects unit: m / s2 when s2 is not registered", %{ctx: ctx} do
      assert {:error, message} =
               Elex.evaluate("10m / (1s * 1s)", ctx, unit: "m | s2")

      assert message == "unknown unit 's2'"
    end

    test "accepts unit: m / s2 when s2 is a registered unit" do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")
        |> Catalog.add_unit!(:time, "s2", "value")
        |> Catalog.add_category!(:velocity, formula: "length | time", default: "m | s")
        |> Catalog.add_unit!(:velocity, "m | s", "value")

      ctx = context(catalog)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10m / 1s", ctx, unit: "m | s2")

      assert %Unit{monomial: %{"m" => 1, "s2" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end

    test "accepts unit: m / s^2 when s is registered", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("10m / (1s * 1s)", ctx, unit: "m | s^2")

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end
  end

  describe "evaluate/3 formula target without :area" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")
      %{ctx: context(catalog)}
    end

    test "converts leftover m * m with unit: m^2 when :area is not registered", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m * 1m", ctx, unit: "m^2")

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "names the target length category when leftover area does not match", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m * 1m", ctx, unit: "m")
      assert message == "expression should return a valid length result"
    end

    test "keeps a sensible error when the target dim is unnamed", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m * 1m", ctx, unit: "m * kg")
      assert message == "expression should return a valid length * mass result"
    end
  end

  describe "caret exponents in derived formulas" do
    test "registers a derived category from length / time^2" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      assert {:ok, catalog} =
               Catalog.add_category(catalog, :acceleration,
                 formula: "length | time^2",
                 default: "m | s^2"
               )

      {:ok, catalog} = Catalog.add_unit(catalog, :acceleration, "m | s^2", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert Elex.validate("10m / (1s * 1s)", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, time: -2}}}
    end

    test "treats length / time^2 as the same dimension as length / (time * time)" do
      catalog = derived_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :accel,
                 formula: "length | time^2",
                 default: "m | s^2"
               )

      assert message =~ ":acceleration"
    end
  end

  defp context(catalog) do
    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  describe "evaluate/2 force identity:" do
    setup do
      %{ctx: context(force_catalog_with_identity())}
    end

    test "keeps an explicit newton as N", %{ctx: ctx} do
      assert Map.has_key?(ctx.units.categories[:force].units, "kg * m | s^2")

      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate("1N", ctx)
      assert %Unit{monomial: %{"N" => 1}} = unit
      refute Map.has_key?(unit.monomial, "kg")
      assert inspect(qty) == "#Elex.Quantity<1 N>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts leftover kg * m / s2 into N when unit: is set", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1kg * 1m / (1s * 1s)", ctx, unit: "N")

      assert %Unit{monomial: %{"N" => 1}} = unit
      assert inspect(qty) == "#Elex.Quantity<1 N>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts named N into the identity formula", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate(~S[convert(1N, "kg * m | s^2")], ctx)

      assert %Unit{monomial: %{"kg" => 1, "m" => 1, "s" => -2}} = unit
      assert inspect(qty) == "#Elex.Quantity<1 kg * m | s^2>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "expands N / kg into leftover m | s^2", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1N / 1kg", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      assert inspect(qty) == "#Elex.Quantity<1 m | s^2>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "keeps 1N * 1N as N^2", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: from_product} = qty} = Elex.evaluate("1N * 1N", ctx)
      assert {:ok, %Elex.Quantity{unit: from_power}} = Elex.evaluate("1N^2", ctx)
      assert %Unit{monomial: %{"N" => 2}} = from_product
      assert Unit.same?(from_product, from_power)
      assert inspect(qty) == "#Elex.Quantity<1 N^2>"
    end

    test "divides 1N^2 by 1N into 1 N", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1N^2 / 1N", ctx)

      assert %Unit{monomial: %{"N" => 1}} = unit
      assert inspect(qty) == "#Elex.Quantity<1 N>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end
  end

  describe "leftover monomial vs derived named unit" do
    test "converts leftover m*m into m2 through the base-hub identity when another formula unit is registered first" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "km", "value * 1000")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m2")

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "km * km", "value * 2")
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")
      ctx = context(catalog)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m * 1m", ctx, unit: "m2")

      assert %Unit{monomial: %{"m2" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts leftover m*m into m2 when area hub is hectares" do
      ctx = hectare_area_context()

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m * 1m", ctx, unit: "m2")

      assert %Unit{monomial: %{"m2" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts leftover m*m into hectares" do
      ctx = hectare_area_context()

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m * 1m", ctx, unit: "ha")

      assert %Unit{monomial: %{"ha" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("0.0001")) == :eq
    end

    test "leftover m*m equals named square metres" do
      ctx = hectare_area_context()
      assert Elex.evaluate("1m * 1m == 1m2", ctx) == {:ok, true}
    end

    test "expands hectares into metres during division" do
      ctx = hectare_area_context()

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1ha / 1m", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("10000")) == :eq
    end

    test "cancels hectares divided by square metres to a decimal" do
      ctx = hectare_area_context()

      assert {:ok, result} = Elex.evaluate("1ha / 1 {m^2}", ctx)
      assert Decimal.compare(result, Decimal.new("10000")) == :eq
    end

    test "named hectares equal leftover after identity formula is registered" do
      ctx = hectare_area_context()
      assert Elex.evaluate("1ha == 10000m2", ctx) == {:ok, true}
    end

    test "converts named hectares into a square-metre formula target" do
      ctx = hectare_area_context()

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1ha", ctx, unit: "m^2")

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("10000")) == :eq
    end

    test "converts named square metres into a square-metre formula target" do
      ctx = hectare_area_context()

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m2", ctx, unit: "m^2")

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts through identity: when the scaled unit name is an equivalent formula" do
      ctx = hectare_identity_equivalent_context()

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m * 1m", ctx, unit: "ha")

      assert %Unit{monomial: %{"ha" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("0.0001")) == :eq
      assert Elex.evaluate("1m * 1m == 1ha", ctx) == {:ok, false}

      assert {:ok, %Elex.Quantity{value: to_mm, unit: to_unit}} =
               Elex.evaluate("1ha", ctx, unit: "m * m")

      assert %Unit{monomial: %{"m" => 2}} = to_unit
      assert Decimal.compare(to_mm, Decimal.new("10000")) == :eq
    end

    test "rejects attaching area with ha hub but no identity" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "ha")

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "ha", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value / 10000")

      assert {:error, message} = Context.put_units(Elex.new_context(), catalog)

      assert message ==
               ~s[derived category :area needs a registered unit matching the base hubs (e.g. "m * m")]
    end
  end

  describe "canonical power aliases" do
    setup do
      %{ctx: context(power_alias_catalog())}
    end

    test "named hectares equal a power-suffix square metre quantity", %{ctx: ctx} do
      assert Elex.evaluate("10000 m^2 == 1ha", ctx) == {:ok, true}
    end

    test "evaluates m2, m^2, and sqm as the canonical m^2 monomial", %{ctx: ctx} do
      for expr <- ["5 m2", "5 m^2", "5 sqm"] do
        assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate(expr, ctx)
        assert %Unit{monomial: %{"m" => 2}} = unit
        refute Map.has_key?(unit.monomial, "m2")
        refute Map.has_key?(unit.monomial, "sqm")
        assert Decimal.compare(value, Decimal.new("5")) == :eq
        assert inspect(qty) == "#Elex.Quantity<5 m^2>"
      end
    end

    test "evaluates cm2 as the canonical cm^2 monomial", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate("5 cm2", ctx)
      assert %Unit{monomial: %{"cm" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("5")) == :eq
      assert inspect(qty) == "#Elex.Quantity<5 cm^2>"
    end

    test "treats 1m2 as the same unit as 1m * 1m", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: from_alias}} = Elex.evaluate("1m2", ctx)
      assert {:ok, %Elex.Quantity{unit: from_product}} = Elex.evaluate("1m * 1m", ctx)
      assert Unit.same?(from_alias, from_product)
    end

    test "divides 1m2 by 1m into 1 m", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1m2 / 1m", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
      assert inspect(qty) == "#Elex.Quantity<1 m>"
    end

    test "evaluates canonical ha and N without rewriting them as formulas", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: ha_unit} = ha} = Elex.evaluate("1ha", ctx)
      assert %Unit{monomial: %{"ha" => 1}} = ha_unit
      assert inspect(ha) == "#Elex.Quantity<1 ha>"

      assert {:ok, %Elex.Quantity{unit: n_unit} = newton} = Elex.evaluate("1N", ctx)
      assert %Unit{monomial: %{"N" => 1}} = n_unit
      assert inspect(newton) == "#Elex.Quantity<1 N>"
    end

    test "parses an unregistered power suffix as a formula of registered symbols", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} = Elex.evaluate("5 mm^3", ctx)
      assert %Unit{monomial: %{"mm" => 3}} = unit
      assert Decimal.compare(value, Decimal.new("5")) == :eq
      assert inspect(qty) == "#Elex.Quantity<5 mm^3>"
    end

    test "canonicalizes an alias raised to a power", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: unit} = qty} = Elex.evaluate("1m2^2", ctx)
      assert %Unit{monomial: %{"m" => 4}} = unit
      refute Map.has_key?(unit.monomial, "m2")
      assert inspect(qty) == "#Elex.Quantity<1 m^4>"
    end

    test "canonicalizes aliases inside a braced formula", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: from_braces} = qty} = Elex.evaluate("1 {m2 * m2}", ctx)
      assert {:ok, %Elex.Quantity{unit: from_product}} = Elex.evaluate("1m2 * 1m2", ctx)
      assert %Unit{monomial: %{"m" => 4}} = from_braces
      assert Unit.same?(from_braces, from_product)
      assert inspect(qty) == "#Elex.Quantity<1 m^4>"
    end

    test "canonicalizes sqm^2 to m^4", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: unit} = qty} = Elex.evaluate("1sqm^2", ctx)
      assert %Unit{monomial: %{"m" => 4}} = unit
      refute Map.has_key?(unit.monomial, "sqm")
      assert inspect(qty) == "#Elex.Quantity<1 m^4>"
    end
  end

  describe "mixed alias leftover conversion" do
    setup do
      %{ctx: alias_area_context()}
    end

    test "keeps a named m2 alias until arithmetic", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m2", ctx)
      assert %Unit{monomial: %{"m2" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "expands m2 into metres during division", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m2 / 1m", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "cancels 1m2 / 1m / 1m to a dimensionless 1", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("1m2 / 1m / 1m", ctx)
      assert %Decimal{} = result
      assert Decimal.compare(result, Decimal.new("1")) == :eq
    end

    test "adds 1m2 / 1m to a metre", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m2 / 1m + 1m", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end

    test "converts 1m2 / 1m into metres", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m2 / 1m", ctx, unit: "m")

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq

      assert {:ok, via_convert} = Elex.evaluate(~S|convert(1m2 / 1m, "m")|, ctx)
      assert via_convert == %Elex.Quantity{value: value, unit: unit}
    end

    test "converts 1m2 * 1m into cubic metres" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m * m")

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :volume,
          formula: "length * length * length",
          default: "m * m * m"
        )

      {:ok, catalog} = Catalog.add_unit(catalog, :volume, "m * m * m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :volume, "m3", "value")
      ctx = context(catalog)

      assert {:ok, %Elex.Quantity{value: product, unit: product_unit}} =
               Elex.evaluate("1m2 * 1m", ctx)

      assert %Unit{monomial: %{"m" => 3}} = product_unit
      assert Decimal.compare(product, Decimal.new("1")) == :eq

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m2 * 1m", ctx, unit: "m3")

      assert %Unit{monomial: %{"m3" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq

      assert {:ok, %Elex.Quantity{unit: formula_unit}} =
               Elex.evaluate("1m2 * 1m", ctx, unit: "m * m * m")

      assert %Unit{monomial: %{"m" => 3}} = formula_unit
    end
  end

  defp force_catalog_with_identity do
    Catalog.new()
    |> Catalog.add_category!(:length, default: "m")
    |> Catalog.add_unit!(:length, "m")
    |> Catalog.add_category!(:mass, default: "kg")
    |> Catalog.add_unit!(:mass, "kg")
    |> Catalog.add_category!(:time, default: "s")
    |> Catalog.add_unit!(:time, "s")
    |> Catalog.add_category!(:force,
      formula: "mass * length | time^2",
      default: "N",
      identity: "kg * m | s^2"
    )
    |> Catalog.add_unit!(:force, "N")
    |> Catalog.add_unit!(:force, "kg * m | s^2")
  end

  defp power_alias_catalog do
    Catalog.new()
    |> Catalog.add_category!(:length, default: "m")
    |> Catalog.add_unit!(:length, "m", "value")
    |> Catalog.add_unit!(:length, "cm", "value / 100")
    |> Catalog.add_unit!(:length, "mm", "value / 1000")
    |> Catalog.add_category!(:mass, default: "kg")
    |> Catalog.add_unit!(:mass, "kg", "value")
    |> Catalog.add_category!(:time, default: "s")
    |> Catalog.add_unit!(:time, "s", "value")
    |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
    |> Catalog.add_unit!(:area, "m^2", "value", aliases: ["m2", "sqm"])
    |> Catalog.add_unit!(:area, "cm^2", "value / 10000", aliases: ["cm2"])
    |> Catalog.add_unit!(:area, "ha", "value * 10000")
    |> Catalog.add_category!(:force, formula: "mass * length | time^2", default: "N")
    |> Catalog.add_unit!(:force, "N", "value")
    |> Catalog.add_unit!(:force, "kg * m | s^2", "value")
  end

  defp alias_area_context do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :area, formula: "length * length", default: "m * m")

    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value")
    context(catalog)
  end

  defp hectare_identity_equivalent_context do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m")

    {:ok, catalog} =
      Catalog.add_category(catalog, :area,
        formula: "length * length",
        default: "ha",
        identity: "m^2"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :area, "ha")
    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value / 10000")
    context(catalog)
  end

  defp hectare_area_context do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :area, formula: "length * length", default: "ha")

    {:ok, catalog} = Catalog.add_unit(catalog, :area, "ha", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value / 10000")
    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value / 10000")
    context(catalog)
  end

  defp derived_catalog do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "second")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "second", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "hour", "value * 3600")
    {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :area,
        formula: "length * length",
        default: "m * m"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :acceleration,
        formula: "length | time * time",
        default: "m | second * second"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :acceleration, "m | second * second", "value")
    catalog
  end
end
