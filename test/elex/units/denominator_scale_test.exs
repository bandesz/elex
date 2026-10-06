defmodule Elex.Units.DenominatorScaleTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Quantity
  alias Elex.Unit
  alias Elex.Units.Catalog

  describe "scaled consumption units" do
    test "registers L | km, L | 100 km, and mL | 100 km" do
      catalog = consumption_catalog()

      assert {:ok, catalog} = Catalog.add_unit(catalog, :consumption, "L | km", "value")

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "mL | 100 km", "value / 100000")

      assert Map.has_key?(catalog.categories[:consumption].units, "L | km")
      assert Map.has_key?(catalog.categories[:consumption].units, "L | 100 km")
      assert Map.has_key?(catalog.categories[:consumption].units, "mL | 100 km")
    end

    test "rejects L | 100 km when the conversion is value / 50" do
      catalog = consumption_catalog()

      assert {:error, message} =
               Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 50")

      assert message ==
               "unit 'L | 100 km' conversion does not match the scale of its component units"

      refute Map.has_key?(catalog.categories[:consumption].units, "L | 100 km")
    end

    test "rejects L | 100 km when the conversion is value" do
      catalog = consumption_catalog()

      assert {:error, message} = Catalog.add_unit(catalog, :consumption, "L | 100 km", "value")

      assert message ==
               "unit 'L | 100 km' conversion does not match the scale of its component units"

      refute Map.has_key?(catalog.categories[:consumption].units, "L | 100 km")
    end

    test "rejects L | 100 km when the conversion is omitted" do
      catalog = consumption_catalog()

      assert {:error, message} = Catalog.add_unit(catalog, :consumption, "L | 100 km")

      assert message ==
               "unit 'L | 100 km' conversion does not match the scale of its component units"

      refute Map.has_key?(catalog.categories[:consumption].units, "L | 100 km")
    end

    test "rejects mL | 100 km when the conversion ignores the millilitre factor" do
      catalog = consumption_catalog()

      assert {:error, message} =
               Catalog.add_unit(catalog, :consumption, "mL | 100 km", "value / 100")

      assert message ==
               "unit 'mL | 100 km' conversion does not match the scale of its component units"

      refute Map.has_key?(catalog.categories[:consumption].units, "mL | 100 km")
    end

    test "rejects L | 100 km on a length category" do
      catalog = consumption_catalog()

      assert {:error, message} = Catalog.add_unit(catalog, :length, "L | 100 km", "value / 100")

      assert message == "formula 'L | 100 km' does not match the category dimension"
      refute Map.has_key?(catalog.categories[:length].units, "L | 100 km")
    end

    test "rejects a default that includes a denominator coefficient" do
      catalog = hub_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :consumption,
                 formula: "volume | length",
                 default: "L | 100 km"
               )

      assert message ==
               "default unit 'L | 100 km' cannot include a denominator coefficient"

      refute Map.has_key?(catalog.categories, :consumption)
    end

    test "rejects a category formula that includes a denominator coefficient" do
      catalog = hub_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :consumption,
                 formula: "volume | 100 length",
                 default: "L | km"
               )

      assert message == "invalid formula 'volume | 100 length'"
      refute Map.has_key?(catalog.categories, :consumption)

      assert_raise ArgumentError, "invalid formula 'volume | 100 length'", fn ->
        Catalog.add_category!(catalog, :consumption,
          formula: "volume | 100 length",
          default: "L | km"
        )
      end
    end

    test "rejects a scaled identity on a derived category" do
      catalog = hub_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :consumption,
                 formula: "volume | length",
                 default: "L | km",
                 identity: "L | 100 km"
               )

      assert message ==
               "identity 'L | 100 km' does not match the base-hub product of :consumption"

      refute Map.has_key?(catalog.categories, :consumption)
    end

    test "put_units rejects a scaled unit that is not the base-hub identity" do
      catalog =
        hub_catalog()
        |> Catalog.add_category!(:consumption, formula: "volume | length", default: "cons")
        |> Catalog.add_unit!(:consumption, "cons", "value")
        |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100")

      assert {:error, message} = Context.put_units(Elex.new_context(), catalog)

      assert message ==
               ~s[derived category :consumption needs a registered unit matching the base hubs (e.g. "L | km")]
    end

    test "rejects a second name with the same monomial and denominator coefficient" do
      catalog = consumption_catalog()

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")

      assert {:error, message} =
               Catalog.add_unit(catalog, :consumption, "L|100km", "value / 100")

      assert message == "unit 'L|100km' has the same scale as 'L | 100 km'"
      refute Map.has_key?(catalog.categories[:consumption].units, "L|100km")
    end

    test "rejects litre | 100 km when L | 100 km is already registered" do
      catalog = aliased_component_catalog()

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")

      assert {:error, message} =
               Catalog.add_unit(catalog, :consumption, "litre | 100 km", "value / 100")

      assert message == "unit 'litre | 100 km' has the same scale as 'L | 100 km'"
      refute Map.has_key?(catalog.categories[:consumption].units, "litre | 100 km")
    end

    test "rejects L | 100 k when L | 100 km is already registered" do
      catalog = aliased_component_catalog()

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")

      assert {:error, message} =
               Catalog.add_unit(catalog, :consumption, "L | 100 k", "value / 100")

      assert message == "unit 'L | 100 k' has the same scale as 'L | 100 km'"
      refute Map.has_key?(catalog.categories[:consumption].units, "L | 100 k")
    end

    test "registers a different denominator coefficient as a different unit" do
      catalog = consumption_catalog()

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")

      assert {:ok, catalog} = Catalog.add_unit(catalog, :consumption, "L | 50 km", "value / 50")

      assert Map.has_key?(catalog.categories[:consumption].units, "L | 50 km")
    end

    test "put_units attaches consumption when L | km and L | 100 km are registered" do
      catalog = consumption_catalog()

      assert {:ok, catalog} = Catalog.add_unit(catalog, :consumption, "L | km", "value")

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")

      assert {:ok, _ctx} = Context.put_units(Elex.new_context(), catalog)
    end
  end

  describe "scaled consumption literals" do
    setup do
      %{ctx: flow_context()}
    end

    test "evaluates a braced litres per 100 km literal", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "evaluates a compact braced litres per 100 km literal", %{ctx: ctx} do
      assert {:ok, spaced} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert {:ok, compact} = Elex.evaluate("8 {L|100km}", ctx)

      assert_same_quantity(compact, spaced)
      assert_litres_per_100_km(compact, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "validates a braced litres per 100 km literal as volume per length", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("8 {L | 100 km}", ctx)
      assert inspect(dimension) == "#Elex.Dimension<volume | length>"
    end

    test "validates a braced litres per 100 km literal for the consumption category", %{
      ctx: ctx
    } do
      assert {:ok, dimension} = Elex.validate("8 {L | 100 km}", ctx)
      assert {:ok, categorized} = Elex.validate("8 {L | 100 km}", ctx, category: :consumption)
      assert categorized == dimension
      assert inspect(categorized) == "#Elex.Dimension<volume | length>"
    end

    test "add_unit wraps a number as the registered litres per 100 km", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate(~S[add_unit(8, "L | 100 km")], ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "evaluates an unbraced litres per 100 km literal", %{ctx: ctx} do
      assert {:ok, braced} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert {:ok, unbraced} = Elex.evaluate("8 L | 100 km", ctx)

      assert_same_quantity(unbraced, braced)
      assert_litres_per_100_km(unbraced, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "evaluates a glued unbraced litres per 100 km literal", %{ctx: ctx} do
      assert {:ok, braced} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert {:ok, glued} = Elex.evaluate("8L|100km", ctx)

      assert_same_quantity(glued, braced)
      assert_litres_per_100_km(glued, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "evaluates an alias of litres per 100 km as that scaled unit" do
      catalog =
        consumption_catalog()
        |> Catalog.add_unit!(:consumption, "L | km", "value")
        |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100", aliases: ["L100km"])

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert {:ok, canonical} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert {:ok, unbraced} = Elex.evaluate("8 L100km", ctx)
      assert {:ok, braced} = Elex.evaluate("8 {L100km}", ctx)

      assert_same_quantity(unbraced, canonical)
      assert_same_quantity(braced, canonical)
      assert_litres_per_100_km(unbraced, "8", "#Elex.Quantity<8 L | 100 km>")

      assert {:ok, dimension} = Elex.validate("8 L100km", ctx)
      assert {:ok, canonical_dimension} = Elex.validate("8 {L | 100 km}", ctx)
      assert dimension == canonical_dimension
    end

    test "multiplies the quantity after an unbraced litres per 100 km suffix", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 L | 100 km * 2", ctx)
      assert_litres_per_100_km(qty, "16", "#Elex.Quantity<16 L | 100 km>")
    end

    test "keeps litres per 100 km on a zero quantity", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("0 {L | 100 km}", ctx)
      assert_litres_per_100_km(qty, "0", "#Elex.Quantity<0 L | 100 km>")
    end

    test "keeps litres per 100 km on a negative quantity", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("-8 {L | 100 km}", ctx)
      assert_litres_per_100_km(qty, "-8", "#Elex.Quantity<-8 L | 100 km>")
    end

    test "rejects an unregistered braced denominator coefficient", %{ctx: ctx} do
      assert Elex.evaluate("8 {L | 50 km}", ctx) == {:error, "unknown unit 'L | 50 km'"}
    end

    test "validate rejects an unregistered braced denominator coefficient", %{ctx: ctx} do
      assert Elex.validate("8 {L | 50 km}", ctx) == {:error, "unknown unit 'L | 50 km'"}
    end

    test "rejects an unregistered unbraced denominator coefficient", %{ctx: ctx} do
      assert Elex.evaluate("8 L | 50 km", ctx) == {:error, "unknown unit 'L | 50 km'"}
    end

    test "rejects a star between the coefficient and the denominator symbol", %{ctx: ctx} do
      assert Elex.evaluate("8 L | 100 * km", ctx) == {:error, "invalid formula 'L | 100 * km'"}
      assert Elex.evaluate("8 {L | 100 * km}", ctx) == {:error, "invalid formula 'L | 100 * km'"}
    end

    test "rejects continuing an unbraced scaled suffix with another kilometre", %{ctx: ctx} do
      assert Elex.evaluate("8 L | 100 km * km", ctx) ==
               {:error,
                "unbraced pipe suffixes cannot continue with '* km'; write a power on the denominator or a braced formula"}
    end

    test "add_unit rejects an unregistered scaled formula", %{ctx: ctx} do
      assert Elex.evaluate(~S[add_unit(8, "L | 50 km")], ctx) ==
               {:error, "add_unit expects a registered unit symbol, got 'L | 50 km'"}
    end
  end

  describe "scaled consumption conversion" do
    setup do
      %{ctx: flow_context()}
    end

    test "converts litres per 100 km into litres per km", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L | 100 km}", ctx, unit: "L | km")
      assert_litres_per_km(qty, "0.08")
    end

    test "converts litres per km into litres per 100 km", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("0.08 {L | km}", ctx, unit: "L | 100 km")
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "convert/2 matches unit: for litres per 100 km into litres per km", %{ctx: ctx} do
      assert {:ok, via_option} = Elex.evaluate("8 {L | 100 km}", ctx, unit: "L | km")
      assert {:ok, via_convert} = Elex.evaluate(~S[convert(8 {L | 100 km}, "L | km")], ctx)

      assert_same_quantity(via_convert, via_option)
      assert_litres_per_km(via_convert, "0.08")
    end

    test "converts millilitres per 100 km into litres per 100 km", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {mL | 100 km}", ctx, unit: "L | 100 km")
      assert_litres_per_100_km(qty, "0.008", "#Elex.Quantity<0.008 L | 100 km>")
    end

    test "rejects an unregistered unit: denominator coefficient", %{ctx: ctx} do
      assert Elex.evaluate("8 {L | 100 km}", ctx, unit: "L | 50 km") ==
               {:error, "unknown unit 'L | 50 km'"}
    end

    test "converts into a compact registered denominator coefficient", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("0.08 {L | km}", ctx, unit: "L|100km")
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "rejects a compact scaled target when the result is a number", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("8", ctx, unit: "L|100km")
      assert message == "cannot convert number to a unit"
    end

    test "rejects a compact scaled target when the result is a comparison", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1 > 0", ctx, unit: "L|100km")
      assert message == "cannot convert yes/no to a unit"
    end

    test "rejects a compact scaled target when the result is text", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~s["hi"], ctx, unit: "L|100km")
      assert message == "cannot convert text to a unit"
    end
  end

  describe "scaled consumption addition" do
    setup do
      %{ctx: flow_context()}
    end

    test "adds two litres per 100 km quantities", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L | 100 km} + 2 {L | 100 km}", ctx)
      assert_litres_per_100_km(qty, "10", "#Elex.Quantity<10 L | 100 km>")
    end

    test "adds litres per km into litres per 100 km", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L | 100 km} + 0.02 {L | km}", ctx)
      assert_litres_per_100_km(qty, "10", "#Elex.Quantity<10 L | 100 km>")
    end

    test "adds litres per 100 km into litres per km", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("0.02 {L | km} + 8 {L | 100 km}", ctx)
      assert_litres_per_km(qty, "0.1")
    end

    test "treats litres per 100 km as equal to the same physical litres per km", %{ctx: ctx} do
      assert Elex.evaluate("8 {L | 100 km} == 0.08 {L | km}", ctx) == {:ok, true}
    end

    test "returns the smaller consumption in the first quantity's unit", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("min(8 {L | 100 km}, 0.1 {L | km})", ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "rejects adding a number to litres per 100 km", %{ctx: ctx} do
      assert Elex.evaluate("8 {L | 100 km} + 1", ctx) ==
               {:error, "cannot add consumption and number"}
    end
  end

  describe "scaled consumption multiplication and division" do
    setup do
      %{ctx: flow_context()}
    end

    test "cancels litres per 100 km against kilometres", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L | 100 km} * 100 km", ctx)

      assert %Quantity{value: value, unit: %Unit{monomial: %{"L" => 1}, per: 1}} = qty
      assert inspect(qty) == "#Elex.Quantity<8 L>"
      assert Decimal.compare(value, Decimal.new("8")) == :eq
    end

    test "cancels litres per 100 km against kilometres per litre into a number", %{ctx: ctx} do
      expr = "8 {L | 100 km} * 12.5 {km | L}"

      assert {:ok, result} = Elex.evaluate(expr, ctx)
      assert %Decimal{} = result
      assert Decimal.compare(result, Decimal.new("1")) == :eq
      assert Elex.validate(expr, ctx) == {:ok, :decimal}
    end

    test "multiplies a number into litres per 100 km", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("2 * 8 {L | 100 km}", ctx)
      assert_litres_per_100_km(qty, "16", "#Elex.Quantity<16 L | 100 km>")
    end

    test "divides litres per 100 km by the same unit into a number", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("8 {L | 100 km} / 2 {L | 100 km}", ctx)
      assert %Decimal{} = result
      assert Decimal.compare(result, Decimal.new("4")) == :eq
    end

    test "folds the product of two litres per 100 km quantities", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L | 100 km} * 3 {L | 100 km}", ctx)

      assert %Quantity{
               value: value,
               unit: %Unit{monomial: %{"L" => 2, "km" => -2}, per: 1}
             } = qty

      assert inspect(qty) == "#Elex.Quantity<0.0024 L^2 | km^2>"
      assert Decimal.compare(value, Decimal.new("0.0024")) == :eq
    end

    test "inverts litres per 100 km into kilometres per litre", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 / 8 {L | 100 km}", ctx)

      assert %Quantity{
               value: value,
               unit: %Unit{monomial: %{"km" => 1, "L" => -1}, per: 1}
             } = qty

      assert inspect(qty) == "#Elex.Quantity<12.5 km | L>"
      assert Decimal.compare(value, Decimal.new("12.5")) == :eq
    end

    test "divides litres per 100 km by litres per km into a number", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("8 {L | 100 km} / 0.02 {L | km}", ctx)
      assert %Decimal{} = result
      assert Decimal.compare(result, Decimal.new("4")) == :eq
    end

    test "rejects division by a zero litres per 100 km quantity", %{ctx: ctx} do
      assert Elex.evaluate("1 / 0 {L | 100 km}", ctx) == {:error, "division by zero"}
    end

    test "keeps a registered denominator coefficient when a product lands on it" do
      catalog =
        consumption_catalog()
        |> Catalog.add_unit!(:consumption, "L | km", "value")
        |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")
        |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
        |> Catalog.add_unit!(:flow, "L | s", "value")
        |> Catalog.add_unit!(:flow, "L | 100 s", "value / 100")
        |> Catalog.add_category!(:pace, formula: "time | length", default: "s | km")
        |> Catalog.add_unit!(:pace, "s | km", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert {:ok, qty} = Elex.evaluate("8 {L | 100 s} * 1 {s | km}", ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "keeps a registered denominator coefficient when a quotient lands on it" do
      catalog =
        consumption_catalog()
        |> Catalog.add_unit!(:consumption, "L | km", "value")
        |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")
        |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
        |> Catalog.add_unit!(:flow, "L | s", "value")
        |> Catalog.add_unit!(:flow, "L | 100 s", "value / 100")
        |> Catalog.add_category!(:pace, formula: "time | length", default: "s | km")
        |> Catalog.add_unit!(:pace, "s | km", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert {:ok, qty} = Elex.evaluate("8 {L | 100 s} / 1 {km | s}", ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "folds an uneven cross-category quotient into physical pace" do
      ctx = uneven_denominator_context()

      assert {:ok, qty} = Elex.evaluate("8 {L | 50 km} / 2 {L | 100 s}", ctx)
      assert {:ok, pace} = Elex.evaluate("8 {s | km}", ctx)

      assert %Quantity{
               value: value,
               unit: %Unit{monomial: %{"s" => 1, "km" => -1}, per: 1}
             } = qty

      assert inspect(qty) == "#Elex.Quantity<8 s | km>"
      assert Decimal.compare(value, Decimal.new("8")) == :eq
      assert_same_quantity(qty, pace)
    end

    test "validates an uneven cross-category quotient as unscaled pace" do
      ctx = uneven_denominator_context()
      expr = "8 {L | 50 km} / 2 {L | 100 s}"

      assert {:ok, pace} = Elex.validate("8 {s | km}", ctx)
      assert Elex.validate(expr, ctx) == {:ok, pace}
    end
  end

  describe "non-additive scaled consumption" do
    setup do
      %{ctx: non_additive_scale_context()}
    end

    test "rejects comparing litres per 100 km with litres per 50 km", %{ctx: ctx} do
      expr = "8 {L | 100 km} == 4 {L | 50 km}"

      assert {:error, message} = Elex.evaluate(expr, ctx)
      assert message == "cannot mix units of non-additive consumption"
      assert {:error, ^message} = Elex.validate(expr, ctx)
    end

    test "rejects min of litres per 100 km and litres per 50 km", %{ctx: ctx} do
      expr = "min(8 {L | 100 km}, 4 {L | 50 km})"

      assert {:error, message} = Elex.evaluate(expr, ctx)
      assert message == "cannot mix units of non-additive consumption"
      assert {:error, ^message} = Elex.validate(expr, ctx)
    end

    test "validates equality of the same litres per 100 km unit", %{ctx: ctx} do
      assert Elex.validate("8 {L | 100 km} == 4 {L | 100 km}", ctx) == {:ok, :boolean}
    end

    test "validates min of the same litres per 100 km unit", %{ctx: ctx} do
      assert {:ok, dimension} =
               Elex.validate("min(8 {L | 100 km}, 4 {L | 100 km})", ctx)

      assert inspect(dimension) == "#Elex.Dimension<volume | length>"
    end
  end

  describe "non-additive products and quotients that keep a scale" do
    setup do
      %{ctx: non_additive_keep_scale_context()}
    end

    test "agrees when a product keeps litres per 100 km", %{ctx: ctx} do
      expr = "(8 {L | 100 s} * 1 {s | km}) == 8 {L | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "agrees on min of a kept product and litres per 100 km", %{ctx: ctx} do
      expr = "min(8 {L | 100 s} * 1 {s | km}, 8 {L | 100 km})"

      assert {:ok, qty} = Elex.evaluate(expr, ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")

      assert {:ok, dimension} = Elex.validate(expr, ctx)
      assert inspect(dimension) == "#Elex.Dimension<volume | length>"
    end

    test "rejects products that differ in per", %{ctx: ctx} do
      expr = "(8 {L | 100 s} * 1 {s | km}) == (8 {L | 50 s} * 1 {s | km})"

      assert {:error, message} = Elex.evaluate(expr, ctx)
      assert message == "cannot mix units of non-additive consumption"
      assert {:error, ^message} = Elex.validate(expr, ctx)
    end

    test "rejects min of products that differ in per", %{ctx: ctx} do
      expr = "min(8 {L | 100 s} * 1 {s | km}, 8 {L | 50 s} * 1 {s | km})"

      assert {:error, message} = Elex.evaluate(expr, ctx)
      assert message == "cannot mix units of non-additive consumption"
      assert {:error, ^message} = Elex.validate(expr, ctx)
    end

    test "agrees when a quotient keeps litres per 100 km", %{ctx: ctx} do
      expr = "(8 {L | 100 s} / 1 {km | s}) == 8 {L | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end
  end

  describe "non-additive folds back to per 1" do
    test "agrees when an uneven quotient folds pace back to per 1" do
      ctx = non_additive_pace_context()
      expr = "8 {L | 50 km} / 2 {L | 100 s} == 8 {s | km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "agrees when an unregistered product scale folds consumption back to per 1" do
      ctx = unregistered_consumption_scale_context()
      expr = "(8 {L | 100 s} * 1 {s | km}) == 0.08 {L | km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end
  end

  describe "scaled alias inside a formula" do
    setup do
      %{ctx: scaled_alias_context()}
    end

    test "rejects a scaled alias inside another formula", %{ctx: ctx} do
      message = "unit 'L100km' cannot be used inside another formula"

      assert Elex.evaluate("8 {L100km * h}", ctx) == {:error, message}
      assert Elex.validate("8 {L100km * h}", ctx) == {:error, message}
      assert Elex.evaluate("8 {L100km | 10 h}", ctx) == {:error, message}
      assert Elex.validate("8 {L100km^2}", ctx) == {:error, message}
    end

    test "multiplies a scaled alias by another quantity", %{ctx: ctx} do
      assert {:ok, product} = Elex.evaluate("8 {L100km} * 1 {h}", ctx)

      assert %Quantity{
               value: value,
               unit: %Unit{monomial: %{"L" => 1, "h" => 1, "km" => -1}, per: 1}
             } = product

      assert inspect(product) == "#Elex.Quantity<0.08 L * h | km>"
      assert Decimal.compare(value, Decimal.new("0.08")) == :eq
    end

    test "keeps a single-symbol scaled alias un-normalized", %{ctx: ctx} do
      assert {:ok, braced} = Elex.evaluate("8 {L100km}", ctx)
      assert {:ok, unbraced} = Elex.evaluate("8 L100km", ctx)

      assert_same_quantity(unbraced, braced)
      assert_litres_per_100_km(braced, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "rejects a scaled alias in the denominator of another formula", %{ctx: ctx} do
      message = "unit 'L100km' cannot be used inside another formula"

      assert Elex.evaluate("8 {h | L100km}", ctx) == {:error, message}
      assert Elex.validate("8 {h | L100km}", ctx) == {:error, message}
    end
  end

  describe "registered scale matched through an alias" do
    setup do
      %{ctx: aliased_component_scale_context()}
    end

    test "keeps litres per 100 km when the registered name uses an alias", %{ctx: ctx} do
      assert {:ok, literal} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert {:ok, product} = Elex.evaluate("8 {L | 100 s} * 1 {s | km}", ctx)

      assert_litres_per_100_km(literal, "8", "#Elex.Quantity<8 L | 100 km>")
      assert_same_quantity(product, literal)
      assert_litres_per_100_km(product, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "agrees on a kept alias scale when consumption is non-additive", %{ctx: ctx} do
      expr = "(8 {L | 100 s} * 1 {s | km}) == 8 {L | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end
  end

  describe "registered formula that still contains an alias" do
    setup do
      %{ctx: alias_formula_scale_context()}
    end

    test "keeps litres per 100 km when cancelling an alias flow", %{ctx: ctx} do
      assert {:ok, product} = Elex.evaluate("8 {litre | 100 s} * 1 {s | km}", ctx)
      assert {:ok, base} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert {:ok, alias_literal} = Elex.evaluate("8 {litre | 100 km}", ctx)

      assert_litres_per_100_km(product, "8", "#Elex.Quantity<8 L | 100 km>")
      assert_same_quantity(product, base)
      assert_same_quantity(alias_literal, base)
    end

    test "agrees when a product of alias formulas keeps litres per 100 km", %{ctx: ctx} do
      expr = "(8 {litre | 100 s} * 1 {s | km}) == 8 {litre | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "agrees when an alias formula equals the base symbol", %{ctx: ctx} do
      expr = "(8 {litre | 100 km}) == 8 {L | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "evaluates a compact alias formula as litres per 100 km", %{ctx: ctx} do
      assert {:ok, compact} = Elex.evaluate("8 {litre|100km}", ctx)
      assert {:ok, spaced} = Elex.evaluate("8 {litre | 100 km}", ctx)

      assert_litres_per_100_km(compact, "8", "#Elex.Quantity<8 L | 100 km>")
      assert_same_quantity(compact, spaced)
    end

    test "agrees when a compact alias formula equals the base symbol", %{ctx: ctx} do
      expr = "8 {litre|100km} == 8 {L | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "agrees when a compact alias formula equals the registered spelling", %{ctx: ctx} do
      expr = "8 {litre|100km} == 8 {litre | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "agrees when a compact product keeps litres per 100 km", %{ctx: ctx} do
      assert {:ok, product} = Elex.evaluate("(8 {litre|100 s} * 1 {s|km})", ctx)
      assert_litres_per_100_km(product, "8", "#Elex.Quantity<8 L | 100 km>")

      expr = "(8 {litre|100 s} * 1 {s|km}) == 8 {L | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "agrees when a denominator alias equals the base symbol", %{ctx: ctx} do
      assert {:ok, aliased} = Elex.evaluate("8 {L | 100 k}", ctx)
      assert_litres_per_100_km(aliased, "8", "#Elex.Quantity<8 L | 100 km>")

      expr = "8 {L | 100 k} == 8 {L | 100 km}"

      assert Elex.evaluate(expr, ctx) == {:ok, true}
      assert Elex.validate(expr, ctx) == {:ok, :boolean}
    end

    test "add_unit wraps an alias formula as litres per 100 km", %{ctx: ctx} do
      expr = "add_unit(8, \"litre | 100 km\")"

      assert {:ok, qty} = Elex.evaluate(expr, ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")

      assert Elex.evaluate(expr <> " == 8 {L | 100 km}", ctx) == {:ok, true}
      assert Elex.validate(expr <> " == 8 {L | 100 km}", ctx) == {:ok, :boolean}
    end

    test "convert to an alias formula keeps litres per 100 km", %{ctx: ctx} do
      expr = "convert(8 {L | 100 km}, \"litre | 100 km\")"

      assert {:ok, qty} = Elex.evaluate(expr, ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")

      assert Elex.evaluate(expr <> " == 8 {L | 100 km}", ctx) == {:ok, true}
      assert Elex.validate(expr <> " == 8 {L | 100 km}", ctx) == {:ok, :boolean}
    end
  end

  describe "nested alias of a formula that still contains an alias" do
    setup do
      %{ctx: nested_alias_formula_context()}
    end

    test "keeps one factor of 100 for an alias of an alias formula", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L100km}", ctx)
      assert_litres_per_100_km(qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "rejects the alias inside a larger formula", %{ctx: ctx} do
      message = "unit 'L100km' cannot be used inside another formula"

      assert Elex.evaluate("8 {L100km * h}", ctx) == {:error, message}
      assert Elex.validate("8 {L100km * h}", ctx) == {:error, message}
    end
  end

  describe "scaled alias cannot be registered inside another formula" do
    setup do
      catalog = litre_scale_catalog()
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx, catalog: catalog}
    end

    test "keeps an alias of litres per 100 km at value 8", %{ctx: ctx} do
      assert {:ok, alias_qty} = Elex.evaluate("8 {L100km}", ctx)
      assert {:ok, spelling} = Elex.evaluate("8 {litre | 100 km}", ctx)

      assert_same_quantity(alias_qty, spelling)
      assert_litres_per_100_km(alias_qty, "8", "#Elex.Quantity<8 L | 100 km>")
    end

    test "rejects registration of a formula that contains the alias", %{catalog: catalog} do
      message = "unit 'L100km' cannot be used inside another formula"

      with_flow =
        catalog
        |> Catalog.add_category!(:flow, formula: "volume * time | length", default: "L * h | km")
        |> Catalog.add_unit!(:flow, "L * h | km", "value")

      assert Catalog.add_unit(with_flow, :flow, "L100km * h", "value / 100") ==
               {:error, message}

      with_rate =
        catalog
        |> Catalog.add_category!(:rate, formula: "volume | length * time", default: "L | km * h")
        |> Catalog.add_unit!(:rate, "L | km * h", "value")

      assert Catalog.add_unit(with_rate, :rate, "L100km | 10 h", "value / 1000") ==
               {:error, message}
    end
  end

  defp litre_scale_catalog do
    Catalog.new()
    |> Catalog.add_category!(:volume, default: "L")
    |> Catalog.add_unit!(:volume, "L", "value", aliases: ["litre"])
    |> Catalog.add_category!(:length, default: "km")
    |> Catalog.add_unit!(:length, "km", "value")
    |> Catalog.add_category!(:consumption,
      formula: "volume | length",
      default: "L | km",
      additive: false
    )
    |> Catalog.add_unit!(:consumption, "L | km", "value")
    |> Catalog.add_unit!(:consumption, "litre | 100 km", "value / 100", aliases: ["L100km"])
    |> Catalog.add_category!(:time, default: "h")
    |> Catalog.add_unit!(:time, "h", "value")
  end

  defp nested_alias_formula_context do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:volume, default: "L")
      |> Catalog.add_unit!(:volume, "L", "value", aliases: ["litre"])
      |> Catalog.add_category!(:length, default: "km")
      |> Catalog.add_unit!(:length, "km", "value")
      |> Catalog.add_category!(:consumption,
        formula: "volume | length",
        default: "L | km",
        additive: false
      )
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "litre | 100 km", "value / 100", aliases: ["L100km"])
      |> Catalog.add_category!(:time, default: "h")
      |> Catalog.add_unit!(:time, "h", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp scaled_alias_context do
    catalog =
      consumption_catalog()
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100", aliases: ["L100km"])
      |> Catalog.add_category!(:time, default: "h")
      |> Catalog.add_unit!(:time, "h", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp alias_formula_scale_context do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:volume, default: "L")
      |> Catalog.add_unit!(:volume, "L", "value", aliases: ["litre"])
      |> Catalog.add_category!(:length, default: "km")
      |> Catalog.add_unit!(:length, "km", "value", aliases: ["k"])
      |> Catalog.add_category!(:consumption,
        formula: "volume | length",
        default: "L | km",
        additive: false
      )
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "litre | 100 km", "value / 100")
      |> Catalog.add_category!(:time, default: "s")
      |> Catalog.add_unit!(:time, "s", "value")
      |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
      |> Catalog.add_unit!(:flow, "L | s", "value")
      |> Catalog.add_unit!(:flow, "litre | 100 s", "value / 100")
      |> Catalog.add_category!(:pace, formula: "time | length", default: "s | km")
      |> Catalog.add_unit!(:pace, "s | km", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp aliased_component_scale_context do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:volume, default: "L")
      |> Catalog.add_unit!(:volume, "L", "value", aliases: ["litre"])
      |> Catalog.add_category!(:length, default: "km")
      |> Catalog.add_unit!(:length, "km", "value")
      |> Catalog.add_category!(:consumption,
        formula: "volume | length",
        default: "L | km",
        additive: false
      )
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "litre | 100 km", "value / 100")
      |> Catalog.add_category!(:time, default: "s")
      |> Catalog.add_unit!(:time, "s", "value")
      |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
      |> Catalog.add_unit!(:flow, "L | s", "value")
      |> Catalog.add_unit!(:flow, "L | 100 s", "value / 100")
      |> Catalog.add_category!(:pace, formula: "time | length", default: "s | km")
      |> Catalog.add_unit!(:pace, "s | km", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp non_additive_keep_scale_context do
    catalog =
      Catalog.add_category!(hub_catalog(), :consumption,
        formula: "volume | length",
        default: "L | km",
        additive: false
      )
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100")
      |> Catalog.add_unit!(:consumption, "L | 50 km", "value / 50")
      |> Catalog.add_category!(:time, default: "s")
      |> Catalog.add_unit!(:time, "s", "value")
      |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
      |> Catalog.add_unit!(:flow, "L | s", "value")
      |> Catalog.add_unit!(:flow, "L | 100 s", "value / 100")
      |> Catalog.add_unit!(:flow, "L | 50 s", "value / 50")
      |> Catalog.add_category!(:pace, formula: "time | length", default: "s | km")
      |> Catalog.add_unit!(:pace, "s | km", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp non_additive_scale_context do
    catalog =
      Catalog.add_category!(hub_catalog(), :consumption,
        formula: "volume | length",
        default: "L | km",
        additive: false
      )
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100")
      |> Catalog.add_unit!(:consumption, "L | 50 km", "value / 50")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp non_additive_pace_context do
    catalog =
      consumption_catalog()
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "L | 50 km", "value / 50")
      |> Catalog.add_category!(:time, default: "s")
      |> Catalog.add_unit!(:time, "s", "value")
      |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
      |> Catalog.add_unit!(:flow, "L | s", "value")
      |> Catalog.add_unit!(:flow, "L | 100 s", "value / 100")
      |> Catalog.add_category!(:pace,
        formula: "time | length",
        default: "s | km",
        additive: false
      )
      |> Catalog.add_unit!(:pace, "s | km", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp unregistered_consumption_scale_context do
    catalog =
      Catalog.add_category!(hub_catalog(), :consumption,
        formula: "volume | length",
        default: "L | km",
        additive: false
      )
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_category!(:time, default: "s")
      |> Catalog.add_unit!(:time, "s", "value")
      |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
      |> Catalog.add_unit!(:flow, "L | s", "value")
      |> Catalog.add_unit!(:flow, "L | 100 s", "value / 100")
      |> Catalog.add_category!(:pace, formula: "time | length", default: "s | km")
      |> Catalog.add_unit!(:pace, "s | km", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp uneven_denominator_context do
    catalog =
      consumption_catalog()
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "L | 50 km", "value / 50")
      |> Catalog.add_category!(:time, default: "s")
      |> Catalog.add_unit!(:time, "s", "value")
      |> Catalog.add_category!(:flow, formula: "volume | time", default: "L | s")
      |> Catalog.add_unit!(:flow, "L | s", "value")
      |> Catalog.add_unit!(:flow, "L | 100 s", "value / 100")
      |> Catalog.add_category!(:pace, formula: "time | length", default: "s | km")
      |> Catalog.add_unit!(:pace, "s | km", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp flow_context do
    catalog =
      consumption_catalog()
      |> Catalog.add_unit!(:consumption, "L | km", "value")
      |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100")
      |> Catalog.add_unit!(:consumption, "mL | 100 km", "value / 100000")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp assert_litres_per_km(qty, magnitude) do
    assert %Quantity{
             value: value,
             unit: %Unit{monomial: %{"L" => 1, "km" => -1}, per: 1}
           } = qty

    assert inspect(qty) == "#Elex.Quantity<#{magnitude} L | km>"
    assert Decimal.compare(value, Decimal.new(magnitude)) == :eq
  end

  defp assert_litres_per_100_km(qty, magnitude, expected_inspect) do
    assert %Quantity{
             value: value,
             unit: %Unit{monomial: %{"L" => 1, "km" => -1}, per: 100}
           } = qty

    assert inspect(qty) == expected_inspect
    assert Decimal.compare(value, Decimal.new(magnitude)) == :eq
  end

  defp assert_same_quantity(left, right) do
    assert Decimal.compare(left.value, right.value) == :eq
    assert Unit.same?(left.unit, right.unit)
    assert inspect(left) == inspect(right)
  end

  defp hub_catalog do
    Catalog.new()
    |> Catalog.add_category!(:volume, default: "L")
    |> Catalog.add_unit!(:volume, "L", "value")
    |> Catalog.add_unit!(:volume, "mL", "value / 1000")
    |> Catalog.add_category!(:length, default: "km")
    |> Catalog.add_unit!(:length, "km", "value")
  end

  defp consumption_catalog do
    Catalog.add_category!(hub_catalog(), :consumption,
      formula: "volume | length",
      default: "L | km"
    )
  end

  defp aliased_component_catalog do
    Catalog.new()
    |> Catalog.add_category!(:volume, default: "L")
    |> Catalog.add_unit!(:volume, "L", "value", aliases: ["litre"])
    |> Catalog.add_category!(:length, default: "km")
    |> Catalog.add_unit!(:length, "km", "value", aliases: ["k"])
    |> Catalog.add_category!(:consumption, formula: "volume | length", default: "L | km")
  end
end
