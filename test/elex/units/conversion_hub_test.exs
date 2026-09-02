defmodule Elex.Units.ConversionHubTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Unit
  alias Elex.Units.Catalog

  describe "evaluate/2 conversion hub" do
    setup do
      %{ctx: context(force_catalog())}
    end

    test "keeps an explicit newton as N", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1N", ctx)
      assert %Unit{monomial: %{"N" => 1}} = unit
      assert inspect(%Elex.Quantity{value: value, unit: unit}) == "#Elex.Quantity<1 N>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "keeps kg * m / s2 as a monomial instead of auto-converting to N", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1kg * 1m / (1s * 1s)", ctx)

      assert %Unit{monomial: %{"kg" => 1, "m" => 1, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts kg * m / s2 into N when unit: is set", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1kg * 1m / (1s * 1s)", ctx, unit: "N")

      assert %Unit{monomial: %{"N" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "keeps unregistered g * m / s2 as a monomial", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1g * 1m / (1s * 1s)", ctx)

      assert %Unit{monomial: %{"g" => 1, "m" => 1, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts an explicit N into the registered formula unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1N", ctx, unit: "kg * m | s^2")

      assert %Unit{monomial: %{"kg" => 1, "m" => 1, "s" => -2}} = unit
      assert Unit.same?(unit, Unit.new!(%{"kg" => 1, "m" => 1, "s" => -2}))
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "category: :force accepts a newton", %{ctx: ctx} do
      assert Elex.validate("1N", ctx, category: :force) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, mass: 1, time: -2}}}
    end

    test "expands N / kg into m | s^2 during division", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1N / 1kg", ctx)
      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts N / kg into m | s^2", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1N / 1kg", ctx, unit: "m | s^2")

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "if keeps the expanded unit of N / kg", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(true, 1N / 1kg, 1N / 1kg)", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      refute Map.has_key?(unit.monomial, "N")
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "coalesce keeps the expanded unit of N / kg", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("coalesce(1N / 1kg, 1N / 1kg)", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      refute Map.has_key?(unit.monomial, "N")
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "if else branch converts into the expanded then unit of N / kg", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 1N / 1kg, 2 m|s^2)", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      refute Map.has_key?(unit.monomial, "N")
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end

    test "multiplies N by m by expanding the named hub", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1N * 1m", ctx)
      assert %Unit{monomial: %{"kg" => 1, "m" => 2, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end
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

    test "converts kg * m / s2 into N when unit: is set", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1kg * 1m / (1s * 1s)", ctx, unit: "N")

      assert %Unit{monomial: %{"N" => 1}} = unit
      assert inspect(qty) == "#Elex.Quantity<1 N>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts an explicit N into the identity formula", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate(~S[convert(1N, "kg * m | s^2")], ctx)

      assert %Unit{monomial: %{"kg" => 1, "m" => 1, "s" => -2}} = unit
      assert inspect(qty) == "#Elex.Quantity<1 kg * m | s^2>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "expands N / kg into m | s^2 during division", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate("1N / 1kg", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -2}} = unit
      assert inspect(qty) == "#Elex.Quantity<1 m | s^2>"
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end
  end

  describe "evaluate/3 identity conversion when mass hub is g" do
    setup do
      %{ctx: context(force_catalog_mass_hub_g())}
    end

    test "converts kg * m / s2 into 1 N via the registered identity", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1kg * 1m / (1s * 1s)", ctx, unit: "N")

      assert %Unit{monomial: %{"N" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts g * m / s2 into 0.001 N via the registered identity", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1g * 1m / (1s * 1s)", ctx, unit: "N")

      assert %Unit{monomial: %{"N" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("0.001")) == :eq
    end
  end

  describe "put_units/2 default: completeness" do
    test "rejects attaching when the hub unit is not registered" do
      assert {:error, message} = Context.put_units(Elex.new_context(), force_catalog_without_n())
      assert message =~ "N"
      assert message =~ "force"
    end
  end

  describe "evaluate/2 missing registered default unit" do
    test "keeps the computed monomial when the hub unit was never registered" do
      ctx = %{Elex.new_context() | units: force_catalog_without_n()}

      assert Elex.validate("1kg * 1m / (1s * 1s)", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, mass: 1, time: -2}}}

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1kg * 1m / (1s * 1s)", ctx)

      assert %Unit{monomial: %{"kg" => 1, "m" => 1, "s" => -2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end
  end

  describe "evaluate/2 without converting to the hub" do
    test "keeps the computed monomial instead of converting to a named unit" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m * m")

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert Elex.validate("1m * 2m", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 2}}}

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m * 2m", ctx)
      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq

      assert {:ok, %Elex.Quantity{value: mm_value, unit: mm_unit}} =
               Elex.evaluate("1mm * 1mm", ctx)

      assert %Unit{monomial: %{"mm" => 2}} = mm_unit
      assert Decimal.compare(mm_value, Decimal.new("1")) == :eq
    end
  end

  defp context(catalog) do
    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp force_catalog do
    {:ok, catalog} = Catalog.add_unit(force_catalog_without_n(), :mass, "g", "value / 1000")
    {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :force, "kg * m | s^2", "value")
    catalog
  end

  defp force_catalog_with_identity do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m")
    {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg")
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s")

    {:ok, catalog} =
      Catalog.add_category(catalog, :force,
        formula: "mass * length | time^2",
        default: "N",
        identity: "kg * m | s^2"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :force, "N")
    {:ok, catalog} = Catalog.add_unit(catalog, :force, "kg * m | s^2")
    catalog
  end

  defp force_catalog_mass_hub_g do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "g")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "g", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value * 1000")
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :force,
        formula: "mass * length | time * time",
        default: "N"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :force, "g * m | s^2", "value / 1000")
    catalog
  end

  defp force_catalog_without_n do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :force,
        formula: "mass * length | time * time",
        default: "N"
      )

    catalog
  end
end
