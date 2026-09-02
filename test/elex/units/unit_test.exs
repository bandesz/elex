defmodule Elex.Units.UnitTest do
  use ExUnit.Case, async: true

  alias Elex.Unit
  alias Elex.Units.Catalog

  describe "from_monomial/1" do
    test "builds a unit from a monomial" do
      unit = Unit.from_monomial(%{"m" => 1})

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Map.keys(Map.from_struct(unit)) == [:monomial]
    end

    test "drops zero exponents from the monomial" do
      unit = Unit.from_monomial(%{"m" => 1, "s" => 0})

      assert unit.monomial == %{"m" => 1}
    end

    test "treats trailing digits as part of the atomic symbol" do
      s2 = Unit.from_monomial(%{"s2" => 1})
      {:ok, m2} = Unit.new("m2")

      assert s2.monomial == %{"s2" => 1}
      assert m2.monomial == %{"m2" => 1}
    end

    test "builds a unit from a multi-symbol monomial" do
      unit = Unit.from_monomial(%{"m" => 2})

      assert %Unit{monomial: %{"m" => 2}} = unit
    end

    test "keeps a single exponent-1 symbol as that monomial" do
      unit = Unit.from_monomial(%{"mm" => 1})

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert inspect(unit) == "#Elex.Unit<mm>"
    end

    test "returns nil for an empty monomial" do
      assert Unit.from_monomial(%{}) == nil
    end

    test "inspects a reciprocal monomial with a 1 in the numerator" do
      unit = Unit.from_monomial(%{"m" => -1})

      assert inspect(unit) == "#Elex.Unit<1 | m>"
    end
  end

  describe "new/1" do
    test "parses a formula into a unit monomial" do
      assert {:ok, unit} = Unit.new("m^2")

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert inspect(unit) == "#Elex.Unit<m^2>"
    end

    test "parses a compound product into the same monomial as m^2" do
      assert {:ok, unit} = Unit.new("m * m")

      assert unit.monomial == %{"m" => 2}
      assert inspect(unit) == "#Elex.Unit<m^2>"
    end

    test "parses a monomial map into a unit" do
      assert {:ok, unit} = Unit.new(%{"m" => 1, "s" => -1})

      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
    end

    test "returns an error for an empty monomial" do
      assert Unit.new(%{}) == {:error, "empty unit"}
      assert Unit.new(%{"m" => 0}) == {:error, "empty unit"}
    end

    test "returns an error for an invalid formula" do
      assert {:error, "invalid formula 'm *'"} = Unit.new("m *")
    end
  end

  describe "new!/1" do
    test "returns the unit for a valid formula" do
      unit = Unit.new!("m^2")

      assert unit.monomial == %{"m" => 2}
      assert inspect(unit) == "#Elex.Unit<m^2>"
    end

    test "raises ArgumentError for an empty monomial" do
      assert_raise ArgumentError, "empty unit", fn ->
        Unit.new!(%{})
      end
    end

    test "raises ArgumentError for an invalid formula" do
      assert_raise ArgumentError, "invalid formula 'm *'", fn ->
        Unit.new!("m *")
      end
    end
  end

  describe "same?/2" do
    test "treats spaced and compact formulas as equal" do
      assert Unit.same?(Unit.new!("km | h"), Unit.new!("km|h"))
    end

    test "treats m^2 as the same unit as m * m" do
      assert Unit.same?(Unit.new!("m^2"), Unit.new!("m * m"))
    end
  end

  describe "convertible?/3" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_unit!(:length, "km", "value * 1000")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")
        |> Catalog.add_unit!(:time, "h", "value * 3600")
        |> Catalog.add_category!(:mass, default: "kg")
        |> Catalog.add_unit!(:mass, "kg", "value")

      %{catalog: catalog}
    end

    test "is true when both units have the same catalog dimension", %{catalog: catalog} do
      assert Unit.convertible?(Unit.new!("m"), Unit.new!("km"), catalog)
    end

    test "is false when units have different catalog dimensions", %{catalog: catalog} do
      refute Unit.convertible?(Unit.new!("m"), Unit.new!("kg"), catalog)
    end

    test "is true for leftover monomials with the same dimension", %{catalog: catalog} do
      assert Unit.convertible?(Unit.new!("m | s"), Unit.new!("km | h"), catalog)
    end

    test "is false when either unit has an unknown symbol", %{catalog: catalog} do
      refute Unit.convertible?(Unit.new!("ft"), Unit.new!("ft"), catalog)
      refute Unit.convertible?(Unit.new!("m"), Unit.new!("ft"), catalog)
    end
  end

  describe "compatible?/3" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_unit!(:length, "cm", "value / 100")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")
        |> Catalog.add_category!(:speed, formula: "length | time", default: "m | s")
        |> Catalog.add_unit!(:speed, "m | s", "value")

      %{catalog: catalog}
    end

    test "is true for cm | s versus :speed even when cm/s is unregistered", %{catalog: catalog} do
      assert Catalog.category_for_unit(catalog, "cm | s") == :error
      assert Catalog.category_for_unit(catalog, "cm/s") == :error

      assert Unit.compatible?(Unit.new!("cm | s"), :speed, catalog)
    end

    test "is false for cm | s versus :length", %{catalog: catalog} do
      refute Unit.compatible?(Unit.new!("cm | s"), :length, catalog)
    end
  end

  describe "inspect/1" do
    test "prints a single exponent-1 symbol as that symbol" do
      unit = Unit.from_monomial(%{"N" => 1})

      assert inspect(unit) == "#Elex.Unit<N>"
    end

    test "pretty-prints a squared monomial with a caret" do
      unit = Unit.new!(%{"m" => 2})

      assert inspect(unit) == "#Elex.Unit<m^2>"
    end

    test "pretty-prints a monomial with a pipe" do
      unit = Unit.new!(%{"m" => 1, "s" => -1})

      assert inspect(unit) == "#Elex.Unit<m | s>"
    end

    test "pretty-prints a squared denominator with a caret" do
      unit = Unit.new!(%{"m" => 1, "s" => -2})

      assert inspect(unit) == "#Elex.Unit<m | s^2>"
    end

    test "joins multiple distinct denominator symbols with *" do
      unit = Unit.new!(%{"m" => 1, "s" => -1, "h" => -1})

      assert inspect(unit) == "#Elex.Unit<m | h * s>"
    end

    test "pretty-prints a force leftover as kg * m | s^2" do
      unit = Unit.new!(%{"kg" => 1, "m" => 1, "s" => -2})

      assert inspect(unit) == "#Elex.Unit<kg * m | s^2>"
    end

    test "pretty-prints a compact pipe formula with a spaced bar" do
      assert inspect(Unit.new!("km|h")) == "#Elex.Unit<km | h>"
    end
  end
end
