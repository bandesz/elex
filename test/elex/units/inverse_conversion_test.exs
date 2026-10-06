defmodule Elex.Units.InverseConversionTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog

  @reciprocal "3.785411784 / 1.609344 / value"

  test "registers an inverse reciprocal and attaches the catalog" do
    catalog = consumption_catalog()

    assert {:ok, catalog} = Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")

    assert {:ok, catalog} =
             Catalog.add_unit(catalog, :consumption, "mile | gallon", @reciprocal)

    assert Map.has_key?(catalog.categories[:consumption].units, "L | 100 km")
    assert Map.has_key?(catalog.categories[:consumption].units, "mile | gallon")

    assert {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    assert ctx.units == catalog
  end

  test "rejects an inverse formula with a linear conversion" do
    catalog = consumption_catalog()

    assert {:error, message} = Catalog.add_unit(catalog, :consumption, "mile | gallon", "value")

    assert message == "formula 'mile | gallon' does not match the category dimension"
    refute Map.has_key?(catalog.categories[:consumption].units, "mile | gallon")
  end

  test "rejects an inverse reciprocal on an additive category" do
    catalog = additive_consumption_catalog()

    assert {:error, message} =
             Catalog.add_unit(catalog, :consumption, "mile | gallon", @reciprocal)

    assert message ==
             "reciprocal conversion for 'mile | gallon' is not allowed on additive category :consumption"

    refute Map.has_key?(catalog.categories[:consumption].units, "mile | gallon")
  end

  test "rejects a reciprocal whose dimension is not the inverse" do
    catalog = consumption_catalog()

    assert {:error, message} = Catalog.add_unit(catalog, :consumption, "kg", "2 / value")

    assert message == "formula 'kg' does not match the category dimension"
    refute Map.has_key?(catalog.categories[:consumption].units, "kg")
  end

  test "rejects an inverse formula with a denominator coefficient" do
    catalog = consumption_catalog()

    assert {:error, message} =
             Catalog.add_unit(catalog, :consumption, "mile | 100 gallon", @reciprocal)

    assert message == "formula 'mile | 100 gallon' does not match the category dimension"
    refute Map.has_key?(catalog.categories[:consumption].units, "mile | 100 gallon")
  end

  test "rejects a second unit with the same inverse monomial" do
    {:ok, catalog} =
      Catalog.add_unit(consumption_catalog(), :consumption, "mile | gallon", @reciprocal)

    assert {:error, message} =
             Catalog.add_unit(catalog, :consumption, "mile|gallon", @reciprocal)

    assert message == "unit 'mile|gallon' has the same scale as 'mile | gallon'"
    refute Map.has_key?(catalog.categories[:consumption].units, "mile|gallon")
  end

  test "converts litres per 100 km into miles per gallon" do
    assert {:ok, qty} =
             Elex.evaluate("8 {L | 100 km}", flow_context(), unit: "mile | gallon")

    assert inspect(qty) ==
             "#Elex.Quantity<29.40182291666666666666666666666666 mile | gallon>"
  end

  test "converts that miles per gallon quantity back into litres per 100 km" do
    assert {:ok, mpg} =
             Elex.evaluate("8 {L | 100 km}", flow_context(), unit: "mile | gallon")

    assert {:ok, qty} = Elex.Evaluator.apply_target_unit(mpg, "L | 100 km", flow_context())

    assert inspect(qty) ==
             "#Elex.Quantity<8.000000000000000000000000000000001 L | 100 km>"
  end

  test "converts litres per 100 km into litres per km" do
    assert {:ok, qty} = Elex.evaluate("8 {L | 100 km}", flow_context(), unit: "L | km")

    assert inspect(qty) == "#Elex.Quantity<0.08 L | km>"
  end

  test "reports division by zero when converting zero litres per 100 km" do
    assert Elex.evaluate("0 {L | 100 km}", flow_context(), unit: "mile | gallon") ==
             {:error, "division by zero"}
  end

  test "reports division by zero when converting a zero inverse quantity" do
    ctx = flow_context()

    assert {:ok, mpg} = Elex.evaluate("8 {L | 100 km}", ctx, unit: "mile | gallon")

    assert Elex.Evaluator.apply_target_unit(%{mpg | value: Decimal.new(0)}, "L | 100 km", ctx) ==
             {:error, "division by zero"}
  end

  test "converts a braced miles per gallon literal into litres per 100 km" do
    assert {:ok, qty} =
             Elex.evaluate("8 {mile | gallon}", flow_context(), unit: "L | 100 km")

    assert inspect(qty) ==
             "#Elex.Quantity<29.40182291666666666666666666666666 L | 100 km>"
  end

  test "converts an unbraced miles per gallon literal into litres per 100 km" do
    ctx = flow_context()

    assert {:ok, braced} =
             Elex.evaluate("8 {mile | gallon}", ctx, unit: "L | 100 km")

    assert {:ok, unbraced} = Elex.evaluate("8 mile | gallon", ctx, unit: "L | 100 km")
    assert unbraced == braced
  end

  test "convert/2 of litres per 100 km matches the miles per gallon unit option" do
    ctx = flow_context()

    assert {:ok, via_unit} =
             Elex.evaluate("8 {L | 100 km}", ctx, unit: "mile | gallon")

    assert {:ok, via_convert} =
             Elex.evaluate(~S[convert(8 {L | 100 km}, "mile | gallon")], ctx)

    assert via_convert == via_unit
  end

  test "rejects miles per 100 gallon as an unknown unit" do
    ctx = flow_context()

    assert Elex.evaluate("8 {L | 100 km}", ctx, unit: "mile | 100 gallon") ==
             {:error, "unknown unit 'mile | 100 gallon'"}

    assert Elex.evaluate(~S[convert(8 {L | 100 km}, "mile | 100 gallon")], ctx) ==
             {:error, "unknown unit 'mile | 100 gallon'"}
  end

  test "validates scaled and inverse consumption literals as the consumption dimension" do
    ctx = flow_context()

    assert {:ok, scaled} = Elex.validate("8 {L | 100 km}", ctx)
    assert {:ok, inverse} = Elex.validate("8 {mile | gallon}", ctx)

    assert inverse == scaled
    assert inspect(scaled) == "#Elex.Dimension<volume | length>"
  end

  test "validates a compact inverse formula as the registered consumption unit" do
    ctx = flow_context()

    assert {:ok, spaced} = Elex.validate("8 {mile | gallon}", ctx)
    assert {:ok, compact} = Elex.validate("8 {mile|gallon}", ctx)

    assert compact == spaced
  end

  test "converts a compact miles per gallon literal into litres per 100 km" do
    ctx = flow_context()

    assert {:ok, spaced} = Elex.evaluate("8 {mile | gallon}", ctx, unit: "L | 100 km")
    assert {:ok, compact} = Elex.evaluate("8 {mile|gallon}", ctx, unit: "L | 100 km")

    assert compact == spaced
  end

  test "converts litres per 100 km into a compact miles per gallon target" do
    ctx = flow_context()

    assert {:ok, spaced} = Elex.evaluate("8 {L | 100 km}", ctx, unit: "mile | gallon")
    assert {:ok, compact} = Elex.evaluate("8 {L | 100 km}", ctx, unit: "mile|gallon")

    assert compact == spaced
  end

  test "rejects adding two compact miles per gallon literals" do
    ctx = flow_context()
    expr = "8 {mile|gallon} + 1 {mile|gallon}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}
  end

  test "rejects adding scaled consumption and a compact miles per gallon literal" do
    ctx = flow_context()
    expr = "8 {L | 100 km} + 1 {mile|gallon}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}
  end

  test "rejects adding scaled and inverse consumption quantities" do
    ctx = flow_context()
    expr = "8 {L | 100 km} + 1 {mile | gallon}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}
  end

  test "rejects adding two miles per gallon literals as non-additive consumption" do
    ctx = flow_context()

    {:ok, ast, _type} =
      Elex.Parser.parse("8 {mile | gallon} + 1 {mile | gallon}", ctx, validate: false)

    assert Elex.Evaluator.evaluate(ast, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}
  end

  test "reports division by zero when converting a zero miles per gallon literal" do
    assert Elex.evaluate("0 {mile | gallon}", flow_context(), unit: "L | 100 km") ==
             {:error, "division by zero"}
  end

  test "inverts litres per 100 km into kilometres per litre" do
    ctx = flow_context()
    expr = "1 / 8 {L | 100 km}"

    assert {:ok, qty} = Elex.evaluate(expr, ctx)
    assert inspect(qty) == "#Elex.Quantity<12.5 km | L>"

    assert {:ok, inverted} = Elex.validate(expr, ctx)
    assert {:ok, kilometres_per_litre} = Elex.validate("1 {km | L}", ctx)
    assert inverted == kilometres_per_litre
  end

  test "cancels litres per 100 km against kilometres into litres" do
    ctx = flow_context()
    expr = "8 {L | 100 km} * 100 km"

    assert {:ok, qty} = Elex.evaluate(expr, ctx)
    assert inspect(qty) == "#Elex.Quantity<8 L>"

    assert {:ok, cancelled} = Elex.validate(expr, ctx)
    assert {:ok, litres} = Elex.validate("8 {L}", ctx)
    assert cancelled == litres
  end

  test "rejects adding two litres per 100 km quantities" do
    ctx = flow_context()
    expr = "8 {L | 100 km} + 2 {L | 100 km}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '+'"}
  end

  test "rejects multiplying litres per 100 km by a number" do
    ctx = flow_context()
    expr = "2 * 8 {L | 100 km}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}
  end

  test "rejects dividing litres per 100 km by a number" do
    ctx = flow_context()
    expr = "8 {L | 100 km} / 2"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}
  end

  test "rejects multiplying miles per gallon by a number" do
    ctx = flow_context()
    expr = "2 * 8 {mile | gallon}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}
  end

  test "rejects inverting miles per gallon" do
    ctx = flow_context()
    expr = "1 / 8 {mile | gallon}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot use non-additive consumption with '*' or '/'"}
  end

  test "rejects comparing litres per 100 km with litres per km" do
    ctx = flow_context()
    expr = "8 {L | 100 km} == 0.08 {L | km}"

    assert Elex.evaluate(expr, ctx) ==
             {:error, "cannot mix units of non-additive consumption"}

    assert Elex.validate(expr, ctx) ==
             {:error, "cannot mix units of non-additive consumption"}
  end

  defp flow_context do
    catalog =
      consumption_catalog()
      |> Catalog.add_unit!(:consumption, "L | 100 km", "value / 100")
      |> Catalog.add_unit!(:consumption, "mile | gallon", @reciprocal)

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end

  defp consumption_catalog do
    component_catalog()
    |> Catalog.add_category!(:consumption,
      formula: "volume | length",
      default: "L | km",
      additive: false
    )
    |> Catalog.add_unit!(:consumption, "L | km", "value")
  end

  defp additive_consumption_catalog do
    component_catalog()
    |> Catalog.add_category!(:consumption,
      formula: "volume | length",
      default: "L | km",
      additive: true
    )
    |> Catalog.add_unit!(:consumption, "L | km", "value")
  end

  defp component_catalog do
    Catalog.new()
    |> Catalog.add_category!(:volume, default: "L")
    |> Catalog.add_unit!(:volume, "L", "value")
    |> Catalog.add_unit!(:volume, "gallon", "value * 3.785411784")
    |> Catalog.add_category!(:length, default: "km")
    |> Catalog.add_unit!(:length, "km", "value")
    |> Catalog.add_unit!(:length, "mile", "value * 1.609344")
  end
end
