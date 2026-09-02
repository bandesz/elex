defmodule Elex.Units.ConvertTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Units.Temperature

  describe "length" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m * m")

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "converts a sum into millimetres", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|convert(1m + 1mm, "mm")|, ctx)

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1001")) == :eq
    end

    test "matches evaluate with unit: for the same expression", %{ctx: ctx} do
      assert {:ok, via_option} = Elex.evaluate("1m + 1mm", ctx, unit: "mm")
      assert {:ok, via_convert} = Elex.evaluate(~S|convert(1m + 1mm, "mm")|, ctx)
      assert via_option == via_convert
    end

    test "converts leftover area into a formula target", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|convert(1m * 2m, "m^2")|, ctx)

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end

    test "validates as the first argument's category", %{ctx: ctx} do
      assert Elex.validate(~S|convert(1m + 1mm, "mm")|, ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "rejects a dimensionless first argument", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~S|convert(1, "mm")|, ctx)
      assert message == "cannot convert a number"
    end

    test "rejects a null first argument", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~S|convert(null, "mm")|, ctx)
      assert message == "convert function expects a unitful value, got empty"
    end

    test "rejects a non-string target", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("convert(1m, 1)", ctx)
      assert message == "convert function expects a string unit, got decimal"
    end

    test "rejects a target of a different category", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~S|convert(1m, "kg")|, ctx)
      assert message =~ "cannot convert length to mass"
    end

    test "rejects a target of a different category at validate time", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~S|convert(1m, "kg")|, ctx)
      assert message =~ "cannot convert length to mass"
    end

    test "rejects a cancelled formula target", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~s[convert(1m, "m | m")], ctx)
      assert message == "invalid formula 'm | m'"
    end

    test "rejects an unknown target at validate time", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~s[convert(1m, "nope")], ctx)
      assert message == "unknown unit 'nope'"
    end

    test "rejects a same-category formula target", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~s[convert(1m, "m | mm")], ctx)

      assert message ==
               "formula 'm | mm' repeats category :length in the numerator and denominator"
    end

    test "rejects a dimensionless formula target", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~S|convert(1m, "m^0")|, ctx)
      assert message == "invalid formula 'm^0'"
    end

    test "converts nested convert calls through the intermediate unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|convert(convert(1m, "mm"), "cm")|, ctx)

      assert %Unit{monomial: %{"cm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("100")) == :eq
    end
  end

  describe "canonical power aliases" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2", "value", aliases: ["m2", "sqm"])

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "converts leftover area into an alias of m^2", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit} = qty} =
               Elex.evaluate(~S|convert(1m * 1m, "m2")|, ctx)

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
      assert inspect(qty) == "#Elex.Quantity<1 m^2>"
    end
  end

  describe "formula-named units match component conversion" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m")
        |> Catalog.add_unit!(:length, "cm", "value / 100")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2")
        |> Catalog.add_unit!(:area, "cm^2", "value / 10000")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "converts 1cm^2 into the registered cm^2 as identity", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|convert(1cm^2, "cm^2")|, ctx)

      assert %Unit{monomial: %{"cm" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts 1cm * 1cm into registered cm^2", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|convert(1cm * 1cm, "cm^2")|, ctx)

      assert %Unit{monomial: %{"cm" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end
  end

  describe "temperature" do
    setup do
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog())
      %{ctx: ctx}
    end

    test "converts 32F to 0 C", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|convert(32F, "C")|, ctx)

      assert %Unit{monomial: %{"C" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("0")) == :eq
    end

    test "rejects dividing a non-additive convert result by time on validate", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~S|convert(32F, "C") / 1s|, ctx)
      assert message == "cannot use non-additive temperature with '*' or '/'"
    end

    test "rejects dividing a non-additive convert result by time on evaluate", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~S|convert(32F, "C") / 1s|, ctx)
      assert message == "cannot use non-additive temperature with '*' or '/'"
    end

    test "rejects a compound target that includes non-additive F", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~S[convert(1Cps, "F | s")], ctx)
      assert message == "cannot use non-additive unit 'F' in a compound target"
    end

    test "rejects a compound non-additive target at validate time", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~S[convert(1Cps, "F | s")], ctx)
      assert message == "cannot use non-additive unit 'F' in a compound target"
    end

    test "rejects a dim-mismatched compound non-additive target before dim mismatch", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~S[convert(1C, "F | s")], ctx)
      assert message == "cannot use non-additive unit 'F' in a compound target"

      assert {:error, ^message} = Elex.validate(~S[convert(1C, "F | s")], ctx)
    end
  end

  describe "derived identity formulas" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m")
        |> Catalog.add_category!(:mass, default: "kg")
        |> Catalog.add_unit!(:mass, "kg")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s")
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

    test "rejects a hectare over square metres as a convert target", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~s[convert(1m * 1m, "ha | m^2")], ctx)

      assert message ==
               "formula 'ha | m^2' repeats category :length in the numerator and denominator"

      assert {:error, ^message} = Elex.evaluate(~s[convert(1m * 1m, "ha | m^2")], ctx)
      assert {:error, eval_message} = Elex.evaluate("1m * 1m", ctx, unit: "ha | m^2")
      assert eval_message == message
    end

    test "rejects a cancelled force identity as a convert target", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~s[convert(1N, "N * s^2 | kg * m")], ctx)

      assert message ==
               "formula 'N * s^2 | kg * m' repeats category :length in the numerator and denominator"
    end
  end

  defp catalog do
    # Cps is a named temperature/time unit so convert(1Cps, "F | s") can test a
    # compound non-additive target. The units guide's linear Cps example is a
    # different catalog shape; this derived category exists only to match dims.
    {:ok, catalog} = Catalog.add_category(Temperature.catalog(), :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :temperature_rate,
        formula: "temperature | time",
        default: "Cps"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :temperature_rate, "Cps", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :temperature_rate, "C | s", "value")
    catalog
  end
end
