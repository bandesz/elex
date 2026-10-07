defmodule Elex.Units.NotDerivableTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Variable

  @mpg_reciprocal "3.785411784 / 1.609344 / value"

  describe "add_unit/5 derivable flag" do
    test "derivable: false is stored on that unit and not on m^3" do
      catalog = volume_catalog(derivable: false)

      assert Map.get(catalog.categories[:volume].units["L"], :derivable) == false
      refute Map.has_key?(catalog.categories[:volume].units["m^3"], :derivable)
    end

    test "derivable: true stores no derivable key" do
      catalog = volume_catalog(derivable: true)

      refute Map.has_key?(catalog.categories[:volume].units["L"], :derivable)
    end

    test "an omitted flag stores no derivable key" do
      catalog = volume_catalog()

      refute Map.has_key?(catalog.categories[:volume].units["L"], :derivable)
    end

    test "derivable: \"no\" is rejected" do
      assert Catalog.add_unit(length_volume_catalog(), :volume, "L", "value / 1000",
               derivable: "no"
             ) == {:error, "derivable: must be a boolean"}
    end
  end

  describe "symbol contribution" do
    test "an alias of not-derivable L contributes the volume atom" do
      catalog = volume_catalog(derivable: false, aliases: ["alias"])

      assert Catalog.unit_dim(catalog, %{"alias" => 1}) == {:ok, %{volume: 1}}
    end

    test "not-derivable L against km keeps volume and length" do
      catalog = volume_catalog(derivable: false)

      assert Catalog.unit_dim(catalog, %{"L" => 1, "km" => -1}) ==
               {:ok, %{volume: 1, length: -1}}
    end

    test "L | km on volume does not repeat length when L is not derivable" do
      catalog = volume_catalog(derivable: false)

      assert Catalog.add_unit(catalog, :volume, "L | km", "value") ==
               {:error, "formula 'L | km' does not match the category dimension"}
    end

    test "L | km on volume repeats length when the mark is omitted" do
      catalog = volume_catalog()

      assert Catalog.add_unit(catalog, :volume, "L | km", "value") ==
               {:error,
                "formula 'L | km' repeats category :length in the numerator and denominator"}
    end

    test "m^3 | m repeats length" do
      catalog = volume_catalog(derivable: false)

      assert Catalog.add_unit(catalog, :volume, "m^3 | m", "value") ==
               {:error,
                "formula 'm^3 | m' repeats category :length in the numerator and denominator"}
    end

    test "cm^3 | m repeats length" do
      catalog = volume_catalog(derivable: false)

      assert Catalog.add_unit(catalog, :volume, "cm^3 | m", "value") ==
               {:error,
                "formula 'cm^3 | m' repeats category :length in the numerator and denominator"}
    end
  end

  describe "fuel nominal dimension" do
    test "registers fuel as volume over length" do
      catalog = volume_catalog(derivable: false)

      assert {:ok, catalog} =
               Catalog.add_category(catalog, :fuel,
                 formula: "volume | length",
                 default: "L | km"
               )

      assert {:ok, dimension} = Catalog.dimension(catalog, :fuel)
      assert inspect(dimension) == "#Elex.Dimension<volume | length>"
      assert dimension.monomial == %{volume: 1, length: -1}
    end

    test "registers L | km on fuel when litre is not derivable" do
      catalog = fuel_catalog()

      assert {:ok, catalog} = Catalog.add_unit(catalog, :fuel, "L | km", "value")
      assert Map.has_key?(catalog.categories[:fuel].units, "L | km")
    end

    test "L | km on fuel repeats length when the mark is omitted" do
      catalog = unmarked_fuel_catalog()

      assert Catalog.add_unit(catalog, :fuel, "L | km", "value") ==
               {:error,
                "formula 'L | km' repeats category :length in the numerator and denominator"}
    end

    test "m^3 | m on fuel repeats length" do
      catalog = fuel_catalog()

      assert Catalog.add_unit(catalog, :fuel, "m^3 | m", "value") ==
               {:error,
                "formula 'm^3 | m' repeats category :length in the numerator and denominator"}
    end

    test "cm^3 | m on fuel repeats length" do
      catalog = fuel_catalog()

      assert Catalog.add_unit(catalog, :fuel, "cm^3 | m", "value") ==
               {:error,
                "formula 'cm^3 | m' repeats category :length in the numerator and denominator"}
    end

    test "rejects identity: when the formula names a derived category" do
      catalog = volume_catalog(derivable: false)

      assert {:error, message} =
               Catalog.add_category(catalog, :fuel,
                 formula: "volume | length",
                 default: "L | km",
                 identity: "m^3 | m"
               )

      assert message ==
               "identity: is not allowed when :fuel formula names a derived category"

      refute Map.has_key?(Catalog.categories(catalog), :fuel)
    end

    test "rejects a fuel default that includes a denominator coefficient" do
      catalog = volume_catalog(derivable: false)

      assert {:error, message} =
               Catalog.add_category(catalog, :fuel,
                 formula: "volume | length",
                 default: "L | 100 km"
               )

      assert message ==
               "default unit 'L | 100 km' cannot include a denominator coefficient"

      refute Map.has_key?(Catalog.categories(catalog), :fuel)
    end

    test "rejects a second category with the same nominal dimension" do
      catalog = fuel_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :economy,
                 formula: "volume | length",
                 default: "L | m"
               )

      assert message == "category :economy has the same dimension as :fuel"
      refute Map.has_key?(Catalog.categories(catalog), :economy)
    end

    test "put_units asks for a per-1 unit of the nominal dimension" do
      {:ok, catalog} =
        volume_catalog(derivable: false)
        |> Catalog.add_category(:fuel, formula: "volume | length", default: "rate")

      {:ok, catalog} = Catalog.add_unit(catalog, :fuel, "rate", "value")

      assert {:error, message} = Context.put_units(Elex.new_context(), catalog)

      assert message ==
               "derived category :fuel needs a registered per-1 unit whose dimension is volume | length"
    end

    test "put_units accepts fuel once L | km is registered" do
      catalog = fuel_catalog()
      assert {:ok, catalog} = Catalog.add_unit(catalog, :fuel, "L | km", "value")

      assert {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      assert Map.has_key?(ctx.units.categories[:fuel].units, "L | km")
      refute Map.has_key?(ctx.units.categories[:fuel].units, "m^3 | m")
    end
  end

  describe "scale check against the nominal hub" do
    test "registers L | 100 km at value / 100" do
      catalog = fuel_catalog()

      assert {:ok, catalog} = Catalog.add_unit(catalog, :fuel, "L | km", "value")

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :fuel, "L | 100 km", "value / 100")

      assert Map.has_key?(catalog.categories[:fuel].units, "L | 100 km")
    end

    test "rejects L | 100 km when the conversion is value" do
      catalog = fuel_catalog()

      assert {:error, message} = Catalog.add_unit(catalog, :fuel, "L | 100 km", "value")

      assert message ==
               "unit 'L | 100 km' conversion does not match the scale of its component units"

      refute Map.has_key?(catalog.categories[:fuel].units, "L | 100 km")
    end

    test "rejects mL | 100 km when the conversion ignores the millilitre factor" do
      catalog = fuel_catalog_with_millilitre()

      assert {:error, message} =
               Catalog.add_unit(catalog, :fuel, "mL | 100 km", "value / 100")

      assert message ==
               "unit 'mL | 100 km' conversion does not match the scale of its component units"

      refute Map.has_key?(catalog.categories[:fuel].units, "mL | 100 km")
    end

    test "registers mL | 100 km at value / 100000" do
      catalog = fuel_catalog_with_millilitre()

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :fuel, "mL | 100 km", "value / 100000")

      assert Map.has_key?(catalog.categories[:fuel].units, "mL | 100 km")
    end

    test "rejects L|100km when L | 100 km is already registered" do
      catalog = fuel_catalog()

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :fuel, "L | 100 km", "value / 100")

      assert {:error, message} =
               Catalog.add_unit(catalog, :fuel, "L|100km", "value / 100")

      assert message == "unit 'L|100km' has the same scale as 'L | 100 km'"
      refute Map.has_key?(catalog.categories[:fuel].units, "L|100km")
    end
  end

  describe "cross-category composition keeps litre" do
    setup do
      %{ctx: composition_context(), catalog: composition_catalog()}
    end

    test "divides litres by metres into litres per metre", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 L / 1 m", ctx)
      assert inspect(qty) == "#Elex.Quantity<1 L | m>"
    end

    test "validates litres per metre as volume per length", %{ctx: ctx} do
      assert Elex.validate("1 L / 1 m", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{volume: 1, length: -1}}}

      assert {:ok, dimension} = Elex.validate("1 L / 1 m", ctx)
      assert inspect(dimension) == "#Elex.Dimension<volume | length>"
    end

    test "divides litres by kilometres into litres per kilometre", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 L / 1 km", ctx)
      assert inspect(qty) == "#Elex.Quantity<1 L | km>"
    end

    test "validates litres per kilometre as volume per length", %{ctx: ctx} do
      assert {:ok, by_metre} = Elex.validate("1 L / 1 m", ctx)
      assert {:ok, by_kilometre} = Elex.validate("1 L / 1 km", ctx)
      assert by_kilometre == by_metre
      assert inspect(by_kilometre) == "#Elex.Dimension<volume | length>"
    end

    test "evaluates a litres per 100 km literal", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 L | 100 km", ctx)
      assert inspect(qty) == "#Elex.Quantity<8 L | 100 km>"
    end

    test "evaluates a glued litres per 100 km literal as the spaced unit", %{ctx: ctx} do
      assert {:ok, spaced} = Elex.evaluate("8 L | 100 km", ctx)
      assert {:ok, glued} = Elex.evaluate("8 L|100km", ctx)
      assert glued == spaced
      assert inspect(glued) == "#Elex.Quantity<8 L | 100 km>"
    end

    test "validates a braced litres per 100 km literal as volume per length", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("8 {L | 100 km}", ctx)
      assert inspect(dimension) == "#Elex.Dimension<volume | length>"
    end

    test "converts litres into cubic metres through the named volume hub", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate(~S|convert(1 L, "m^3")|, ctx)
      assert inspect(qty) == "#Elex.Quantity<0.001 m^3>"
    end

    test "rejects an unregistered litres per 50 km literal", %{ctx: ctx} do
      assert Elex.evaluate("8 {L | 50 km}", ctx) == {:error, "unknown unit 'L | 50 km'"}
    end

    test "does not convert litres per metre into an unregistered square metre", %{ctx: ctx} do
      assert Elex.evaluate("1 L / 1 m", ctx, unit: "m^2") ==
               {:error, "expression should return a valid length^2 result"}
    end

    test "does not convert litres per metre into a metre times metre formula", %{ctx: ctx} do
      assert Elex.evaluate(~S|convert(1 L / 1 m, "m * m")|, ctx) ==
               {:error, "cannot convert fuel to 'm * m'"}
    end

    test "cancels kilometres and leaves litres", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {L | 100 km} * 100 km", ctx)
      assert inspect(qty) == "#Elex.Quantity<8 L>"
    end

    test "validates cancelled kilometres as volume's stored dimension", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("8 {L | 100 km} * 100 km", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length^3>"
      assert dimension.monomial == %{length: 3}
    end

    test "inverts litres per 100 km into kilometres per litre", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 / 8 {L | 100 km}", ctx)
      assert inspect(qty) == "#Elex.Quantity<12.5 km | L>"
    end

    test "validates the inverse as length per volume", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("1 / 8 {L | 100 km}", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length | volume>"
      assert dimension.monomial == %{length: 1, volume: -1}
    end

    test "validates a lone litre as volume's stored dimension", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("1 L", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length^3>"
      assert dimension.monomial == %{length: 3}
    end

    test "rejects adding litres to kilometres", %{ctx: ctx} do
      assert Elex.evaluate("1 L + 1 km", ctx) == {:error, "cannot add volume and length"}
    end

    test "rejects division by a zero litres per 100 km quantity", %{ctx: ctx} do
      assert Elex.evaluate("1 / 0 {L | 100 km}", ctx) == {:error, "division by zero"}
    end

    test "treats litre and cubic metre as convertible", %{catalog: catalog} do
      assert Unit.convertible?(Unit.new!("L"), Unit.new!("m^3"), catalog)
    end

    test "treats litre as compatible with volume", %{catalog: catalog} do
      assert Unit.compatible?(Unit.new!("L"), :volume, catalog)
    end

    test "treats litres per metre as compatible with fuel", %{catalog: catalog} do
      assert Unit.compatible?(Unit.new!("L | m"), :fuel, catalog)
    end
  end

  describe "energy per length needs no derivable mark" do
    test "registers kWh | km and kWh | 100 km" do
      catalog = energy_catalog()

      assert {:ok, catalog} = Catalog.add_unit(catalog, :consumption, "kWh | km", "value")

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :consumption, "kWh | 100 km", "value / 100")

      assert Map.has_key?(catalog.categories[:consumption].units, "kWh | km")
      assert Map.has_key?(catalog.categories[:consumption].units, "kWh | 100 km")
    end

    test "rejects kWh | 100 km when the conversion is value" do
      catalog = energy_catalog()

      assert {:error, message} =
               Catalog.add_unit(catalog, :consumption, "kWh | 100 km", "value")

      assert message ==
               "unit 'kWh | 100 km' conversion does not match the scale of its component units"

      refute Map.has_key?(catalog.categories[:consumption].units, "kWh | 100 km")
    end
  end

  describe "same-category volume addition and division" do
    setup do
      %{ctx: composition_context()}
    end

    test "adds cubic metres into litres", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 L + 1 m^3", ctx)
      assert inspect(qty) == "#Elex.Quantity<1001 L>"
    end

    test "adds litres into cubic metres", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 m^3 + 1 L", ctx)
      assert inspect(qty) == "#Elex.Quantity<1.001 m^3>"
    end

    test "divides litres by cubic metres into a decimal", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("1 L / 1 m^3", ctx)
      assert result == Decimal.new("0.001")
      refute match?(%Elex.Quantity{}, result)
      assert Elex.validate("1 L / 1 m^3", ctx) == {:ok, :decimal}
    end

    test "divides litres by cubic kilometres into a decimal", %{ctx: ctx} do
      assert Elex.validate("1 L / 1 km^3", ctx) == {:ok, :decimal}
      assert {:ok, result} = Elex.evaluate("1 L / 1 km^3", ctx)
      assert result == Decimal.new("1E-12")
      refute match?(%Elex.Quantity{}, result)
    end

    test "adds cubic kilometres into litres", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("1 L + 1 km^3", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length^3>"
      assert dimension.monomial == %{length: 3}

      assert {:ok, qty} = Elex.evaluate("1 L + 1 km^3", ctx)
      assert inspect(qty) == "#Elex.Quantity<1000000000001 L>"
    end

    test "compares a litre with a cubic kilometre", %{ctx: ctx} do
      assert Elex.validate("1 L == 1 km^3", ctx) == {:ok, :boolean}
      assert Elex.evaluate("1 L == 1 km^3", ctx) == {:ok, false}
      assert Elex.evaluate("1 L < 1 km^3", ctx) == {:ok, true}
    end

    test "validates litres plus cubic metres as volume's stored dimension", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("1 L + 1 m^3", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length^3>"
      assert dimension.monomial == %{length: 3}
    end

    test "compares a litre with a thousandth of a cubic metre", %{ctx: ctx} do
      assert Elex.evaluate("1 L == 0.001 m^3", ctx) == {:ok, true}
    end

    test "rejects a litre as greater than a cubic metre", %{ctx: ctx} do
      assert Elex.evaluate("1 L > 1 m^3", ctx) == {:ok, false}
      assert Elex.validate("1 L > 1 m^3", ctx) == {:ok, :boolean}
    end

    test "accepts a cubic metre as greater than a litre", %{ctx: ctx} do
      assert Elex.evaluate("1 m^3 > 1 L", ctx) == {:ok, true}
    end

    test "rejects comparing a litre with a kilometre", %{ctx: ctx} do
      assert Elex.evaluate("1 L > 1 km", ctx) == {:error, "cannot compare volume and length"}
    end

    test "adds kilometre to the sixth into litre squared", %{ctx: ctx} do
      assert {:ok, litres} = Elex.validate("1 L^2", ctx)
      assert inspect(litres) == "#Elex.Dimension<length^6>"

      assert {:ok, kilometres} = Elex.validate("1 km^6", ctx)
      assert inspect(kilometres) == "#Elex.Dimension<length^6>"

      assert {:ok, dimension} = Elex.validate("1 L^2 + 1 km^6", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length^6>"

      assert {:ok, qty} = Elex.evaluate("1 L^2 + 1 km^6", ctx)
      assert inspect(qty) == "#Elex.Quantity<1000000000000000000000001 L^2>"
    end

    test "divides litre squared by kilometre to the sixth into a decimal", %{ctx: ctx} do
      assert Elex.validate("1 L^2 / 1 km^6", ctx) == {:ok, :decimal}

      assert {:ok, result} = Elex.evaluate("1 L^2 / 1 km^6", ctx)
      assert result == Decimal.new("1E-24")
      refute match?(%Elex.Quantity{}, result)
    end

    test "compares litre squared with kilometre to the sixth", %{ctx: ctx} do
      assert Elex.validate("1 L^2 == 1 km^6", ctx) == {:ok, :boolean}
      assert Elex.evaluate("1 L^2 == 1 km^6", ctx) == {:ok, false}
      assert Elex.evaluate("1 L^2 < 1 km^6", ctx) == {:ok, true}
    end

    test "divides per litre by per cubic metre into a decimal", %{ctx: ctx} do
      assert {:ok, per_litre} = Elex.validate("1 / 1 L", ctx)
      assert inspect(per_litre) == "#Elex.Dimension<1 | length^3>"

      assert {:ok, per_cubic_metre} = Elex.validate("1 / 1 m^3", ctx)
      assert inspect(per_cubic_metre) == "#Elex.Dimension<1 | length^3>"

      assert Elex.validate("(1 / 1 L) / (1 / 1 m^3)", ctx) == {:ok, :decimal}
      assert {:ok, result} = Elex.evaluate("(1 / 1 L) / (1 / 1 m^3)", ctx)
      assert Decimal.equal?(result, Decimal.new("1000"))
    end

    test "adds per cubic metre into per litre", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("(1 / 1 L) + (1 / 1 m^3)", ctx)
      assert inspect(qty) == "#Elex.Quantity<1.001 | L>"
    end
  end

  describe "miles per gallon on the nominal fuel dimension" do
    test "registers mile | gallon with the reciprocal that maps to L | km" do
      assert {:ok, catalog} =
               Catalog.add_unit(mpg_catalog(), :fuel, "mile | gallon", @mpg_reciprocal)

      assert Map.has_key?(catalog.categories[:fuel].units, "mile | gallon")
    end

    test "attaches the catalog and converts litres per 100 km into miles per gallon" do
      assert {:ok, ctx} = Context.put_units(Elex.new_context(), mpg_catalog_with_inverse())

      assert {:ok, qty} =
               Elex.evaluate("8 {L | 100 km}", ctx, unit: "mile | gallon")

      assert inspect(qty) ==
               "#Elex.Quantity<29.40182291666666666666666666666666 mile | gallon>"
    end

    test "validates miles per gallon as volume per length" do
      assert {:ok, ctx} = Context.put_units(Elex.new_context(), mpg_catalog_with_inverse())
      assert {:ok, dimension} = Elex.validate("8 {mile | gallon}", ctx)
      assert inspect(dimension) == "#Elex.Dimension<volume | length>"
    end

    test "rejects the reciprocal on an additive fuel category" do
      assert {:error, message} =
               Catalog.add_unit(additive_mpg_catalog(), :fuel, "mile | gallon", @mpg_reciprocal)

      assert message ==
               "reciprocal conversion for 'mile | gallon' is not allowed on additive category :fuel"

      refute Map.has_key?(additive_mpg_catalog().categories[:fuel].units, "mile | gallon")
    end

    test "rejects mile | gallon when the conversion is value" do
      assert {:error, message} =
               Catalog.add_unit(mpg_catalog(), :fuel, "mile | gallon", "value")

      assert message == "formula 'mile | gallon' does not match the category dimension"
      refute Map.has_key?(mpg_catalog().categories[:fuel].units, "mile | gallon")
    end
  end

  describe "powers of length still reduce" do
    setup do
      %{ctx: geometry_context()}
    end

    test "multiplies metres into cubic metres", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 m * 1 m * 1 m", ctx)
      assert inspect(qty) == "#Elex.Quantity<1 m^3>"
      assert qty.unit.monomial == %{"m" => 3}
    end

    test "validates metres cubed as length cubed", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("1 m * 1 m * 1 m", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length^3>"
      assert dimension.monomial == %{length: 3}
    end

    test "divides cubic metres by metres into square metres", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 m^3 / 1 m", ctx)
      assert inspect(qty) == "#Elex.Quantity<1 m^2>"
    end

    test "validates cubic metres over metres as length squared", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("1 m^3 / 1 m", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length^2>"
      assert dimension.monomial == %{length: 2}
    end
  end

  describe "hectare still expands" do
    setup do
      %{ctx: hectare_context()}
    end

    test "divides hectares by metres into metres", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("1 ha / 1 m", ctx)
      assert inspect(qty) == "#Elex.Quantity<10000 m>"
    end

    test "validates hectares over metres as length", %{ctx: ctx} do
      assert {:ok, dimension} = Elex.validate("1 ha / 1 m", ctx)
      assert inspect(dimension) == "#Elex.Dimension<length>"
      assert dimension.monomial == %{length: 1}
    end
  end

  describe "base energy cancels kilometres without a derivable mark" do
    setup do
      catalog =
        energy_catalog()
        |> Catalog.add_unit!(:consumption, "kWh | km", "value")
        |> Catalog.add_unit!(:consumption, "kWh | 100 km", "value / 100")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "cancels kilometres and leaves kilowatt-hours", %{ctx: ctx} do
      assert {:ok, qty} = Elex.evaluate("8 {kWh | 100 km} * 100 km", ctx)
      assert inspect(qty) == "#Elex.Quantity<8 kWh>"
    end
  end

  describe "fuel variable membership" do
    setup do
      catalog = membership_catalog()
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx, catalog: catalog}
    end

    test "stores evaluated litres per metre as a fuel variable", %{ctx: ctx, catalog: catalog} do
      assert {:ok, quantity} = Elex.evaluate("1 L / 1 m", ctx)
      assert Unit.compatible?(quantity.unit, :fuel, catalog)
      assert {:ok, ctx} = Elex.add_variable(ctx, "rate", quantity, category: :fuel)
      assert %Variable{type: :fuel, value: ^quantity} = ctx.variables["rate"]
    end

    test "rejects evaluated litres per metre as area", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("1 L / 1 m", ctx)

      assert {:error, message} =
               Elex.add_variable(ctx, "rate", quantity, category: :area)

      assert message == "unit 'L | m' is not in category area"
    end

    test "stores evaluated litres per 100 km as a fuel variable", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("8 {L | 100 km}", ctx)
      assert {:ok, ctx} = Elex.add_variable(ctx, "rate", quantity, category: :fuel)
      assert %Variable{type: :fuel, value: ^quantity} = ctx.variables["rate"]
    end

    test "stores evaluated litres as a volume variable", %{ctx: ctx} do
      assert {:ok, quantity} = Elex.evaluate("1 L", ctx)
      assert {:ok, ctx} = Elex.add_variable(ctx, "amount", quantity, category: :volume)
      assert %Variable{type: :volume, value: ^quantity} = ctx.variables["amount"]
    end

    test "stores a litre tuple as a volume variable", %{ctx: ctx} do
      assert {:ok, ctx} = Elex.add_variable(ctx, "amount", {1, "L"}, category: :volume)
      assert %Variable{type: :volume, value: {1, "L"}} = ctx.variables["amount"]
    end
  end

  defp membership_catalog do
    composition_catalog()
    |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
    |> Catalog.add_unit!(:area, "m^2", "value")
  end

  defp composition_context do
    {:ok, ctx} = Context.put_units(Elex.new_context(), composition_catalog())
    ctx
  end

  defp composition_catalog do
    fuel_catalog()
    |> Catalog.add_unit!(:fuel, "L | km", "value")
    |> Catalog.add_unit!(:fuel, "L | 100 km", "value / 100")
  end

  defp fuel_catalog do
    {:ok, catalog} =
      volume_catalog(derivable: false)
      |> Catalog.add_category(:fuel, formula: "volume | length", default: "L | km")

    catalog
  end

  defp fuel_catalog_with_millilitre do
    Catalog.add_unit!(fuel_catalog(), :volume, "mL", "value / 1000000", derivable: false)
  end

  defp energy_catalog do
    Catalog.new()
    |> Catalog.add_category!(:energy, default: "kWh")
    |> Catalog.add_unit!(:energy, "kWh", "value")
    |> Catalog.add_category!(:length, default: "km")
    |> Catalog.add_unit!(:length, "km", "value")
    |> Catalog.add_category!(:consumption, formula: "energy | length", default: "kWh | km")
  end

  defp unmarked_fuel_catalog do
    {:ok, catalog} =
      volume_catalog()
      |> Catalog.add_category(:fuel, formula: "volume | length", default: "L | km")

    catalog
  end

  defp volume_catalog(opts \\ []) do
    Catalog.add_unit!(
      length_volume_catalog(),
      :volume,
      "L",
      "value / 1000",
      Keyword.take(opts, [:derivable, :aliases])
    )
  end

  # `cm` is required so the formula parser can register `cm^3` (`cm` cubed).
  defp length_volume_catalog do
    Catalog.new()
    |> Catalog.add_category!(:length, default: "m")
    |> Catalog.add_unit!(:length, "m", "value")
    |> Catalog.add_unit!(:length, "cm", "value / 100")
    |> Catalog.add_unit!(:length, "km", "value * 1000")
    |> Catalog.add_category!(:volume, formula: "length * length * length", default: "m^3")
    |> Catalog.add_unit!(:volume, "m^3", "value")
    |> Catalog.add_unit!(:volume, "cm^3", "value / 1000000")
  end

  defp mpg_catalog do
    catalog =
      volume_catalog(derivable: false)
      |> Catalog.add_unit!(:length, "mile", "value * 1609.344")
      |> Catalog.add_unit!(:volume, "gallon", "value * 0.003785411784", derivable: false)

    {:ok, catalog} =
      Catalog.add_category(catalog, :fuel,
        formula: "volume | length",
        default: "L | km",
        additive: false
      )

    catalog
    |> Catalog.add_unit!(:fuel, "L | km", "value")
    |> Catalog.add_unit!(:fuel, "L | 100 km", "value / 100")
  end

  defp mpg_catalog_with_inverse do
    {:ok, catalog} = Catalog.add_unit(mpg_catalog(), :fuel, "mile | gallon", @mpg_reciprocal)
    catalog
  end

  defp additive_mpg_catalog do
    catalog =
      volume_catalog(derivable: false)
      |> Catalog.add_unit!(:length, "mile", "value * 1609.344")
      |> Catalog.add_unit!(:volume, "gallon", "value * 0.003785411784", derivable: false)

    {:ok, catalog} =
      Catalog.add_category(catalog, :fuel,
        formula: "volume | length",
        default: "L | km",
        additive: true
      )

    catalog
    |> Catalog.add_unit!(:fuel, "L | km", "value")
    |> Catalog.add_unit!(:fuel, "L | 100 km", "value / 100")
  end

  defp geometry_context do
    catalog =
      Catalog.new()
      |> Catalog.add_category!(:length, default: "m")
      |> Catalog.add_unit!(:length, "m", "value")
      |> Catalog.add_category!(:volume, formula: "length * length * length", default: "m^3")
      |> Catalog.add_unit!(:volume, "m^3", "value")
      |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
      |> Catalog.add_unit!(:area, "m^2", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp hectare_context do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m")

    {:ok, catalog} =
      Catalog.add_category(catalog, :area,
        formula: "length * length",
        default: "ha",
        identity: "m^2"
      )

    {:ok, catalog} = Catalog.add_unit(catalog, :area, "ha")
    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m^2", "value / 10000")
    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end
end
