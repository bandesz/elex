defmodule Elex.Units.FunctionsTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Function
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Units.Temperature

  defmodule Double do
    @behaviour Elex.Function

    @impl Elex.Function
    def signature, do: %{name: :double, arity: 1}

    @impl Elex.Function
    def validate([arg_ast], context) do
      case Elex.Validator.same_numeric_type([arg_ast], context) do
        {:ok, type} -> {:ok, type}
        {:mismatch, type} -> {:error, "double expects a number, got " <> inspect(type)}
        {:error, reason} -> {:error, reason}
      end
    end

    @impl Elex.Function
    def call([%Elex.Quantity{value: value, unit: unit}]) do
      {:ok, doubled} = call([value])
      {:ok, %Elex.Quantity{value: doubled, unit: unit}}
    end

    def call([arg]) when is_struct(arg, Decimal) do
      {:ok, Decimal.mult(arg, Decimal.new(2))}
    end

    @impl Elex.Function
    def documentation do
      %{signature: "double(x)", description: "returns x multiplied by 2"}
    end
  end

  defmodule NonePassthrough do
    @behaviour Elex.Function

    @impl Elex.Function
    def signature, do: %{name: :nonefn, arity: 1, units: :none}

    @impl Elex.Function
    def validate([arg_ast], context) do
      case Elex.Validator.validate(arg_ast, context) do
        {:ok, type} -> {:ok, type}
        {:error, reason} -> {:error, reason}
      end
    end

    @impl Elex.Function
    def call([arg]), do: {:ok, arg}

    @impl Elex.Function
    def documentation do
      %{signature: "nonefn(x)", description: "returns the argument"}
    end
  end

  setup do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
    {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    %{ctx: ctx}
  end

  describe "preserve functions keep the unit" do
    test "abs keeps the unit of a negative literal", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("abs(-5mm)", ctx)
      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("5")) == :eq
    end

    test "abs of a unitful value validates as the category", %{ctx: ctx} do
      assert Elex.validate("abs(-5mm)", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "ceil, floor, and round keep the unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("ceil(1.2mm)", ctx)
      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("floor(1.8mm)", ctx)
      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("round(1.5mm)", ctx)
      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end

    test "clamp keeps the first argument's unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("clamp(50cm, 1m, 2m)", ctx)

      assert %Unit{monomial: %{"cm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("100")) == :eq
    end

    test "clamp converts mixed units into the first argument's unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("clamp(1.5mm, 1m, 2m)", ctx)

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "pi times a unit keeps the unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("pi() * 1m", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("3.141592653589793")) == :eq
    end
  end

  describe "min and max convert into the first argument's unit" do
    test "min converts later args into the first unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("min(1m, 10cm)", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("0.1")) == :eq
    end

    test "max converts later args into the first unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("max(1m, 10cm)", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "min of unitful values validates as the category", %{ctx: ctx} do
      assert Elex.validate("min(1m, 10cm)", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "rejects min of mixed categories", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("min(1m, 1kg)", ctx)
      assert message == "cannot mix length and mass"
    end

    test "rejects min of a number and a quantity", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("min(1, 1m)", ctx)
      assert message == "cannot mix number and length"
    end

    test "rejects min of a quantity and a number", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("min(1m, 1)", ctx)
      assert message == "cannot mix length and number"
    end

    test "rejects max of mixed categories", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("max(1m, 1kg)", ctx)
      assert message == "cannot mix length and mass"
    end

    test "rejects clamp of mixed categories", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("clamp(1m, 1kg, 2m)", ctx)
      assert message == "cannot mix length and mass"
    end
  end

  describe "if converts the else branch into the then unit" do
    test "true branch keeps the then unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(true, 1m, 100cm)", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch converts else into the then unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 1m, 100cm)", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch does not evaluate then", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 1m / 0, 100cm)", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch converts else into then unit of max", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, max(1cm, 2m), 1m)", ctx)

      assert %Unit{monomial: %{"cm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("100")) == :eq
    end

    test "false branch converts else into then unit of ceil", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, ceil(1.2cm), 1m)", ctx)

      assert %Unit{monomial: %{"cm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("100")) == :eq
    end

    test "false branch converts else into then unit of dimensionless times unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 2 * 1m, 100cm)", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch converts else into convert then unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|if(false, convert(1m, "mm"), 1m)|, ctx)

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "false branch converts else into add_unit then unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate(~S|if(false, add_unit(5, "mm"), 1m)|, ctx)

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "false branch converts else into coalesce then unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, coalesce(1m, 2m), 100cm)", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch converts else into nested point then unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, coalesce(ceil(1.2m), floor(1.1cm)), 100cm)", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch converts else into custom function then unit", %{ctx: ctx} do
      ctx = Context.add_function(ctx, Double)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, double(1m), 100cm)", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "coalesce of mixed units of the same category uses the first quantity's unit", %{
      ctx: ctx
    } do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("coalesce(ceil(1.2m), floor(1.1cm))", ctx)

      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end

    test "if of unitful branches validates as the category", %{ctx: ctx} do
      assert Elex.validate("if(true, 1m, 100cm)", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "rejects if branches of different categories", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("if(true, 1m, 1kg)", ctx)
      assert message == "if branches must have the same type, got length and mass"
    end

    test "rejects if mixing a number and a length", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("if(true, 1, 1m)", ctx)
      assert message == "if branches must have the same type, got number and length"
    end
  end

  describe "if converts the else branch into a derived then monomial" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed,
          formula: "length | time",
          default: "m | s"
        )

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area,
          formula: "length * length",
          default: "m * m"
        )

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "false branch of a speed if validates as speed", %{ctx: ctx} do
      assert Elex.validate("if(false, 1m / 1s, 2m / 1s)", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1, time: -1}}}
    end

    test "false branch converts else into then speed", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 1m / 1s, 2m / 1s)", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end

    test "true branch evaluates then speed normally", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(true, 1m / 1s, 2m / 1s)", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch of an area if validates as area", %{ctx: ctx} do
      assert Elex.validate("if(false, 1m * 1m, 4m * 1m)", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 2}}}
    end

    test "false branch converts else into then area", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 1m * 1m, 4m * 1m)", ctx)

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("4")) == :eq
    end

    test "false branch converts else into then mixed-length product", %{ctx: ctx} do
      {:ok, catalog} = Catalog.add_unit(ctx.units, :length, "mm", "value / 1000")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 1m * 1mm, 1m * 1m)", ctx)

      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "false branch does not evaluate a derived then that divides by zero", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("if(false, 1m / 1s / 0, 2m / 1s)", ctx)

      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end
  end

  describe "comparisons convert into the left unit" do
    test "same-category comparison evaluates to a boolean", %{ctx: ctx} do
      assert Elex.evaluate("1m > 10cm", ctx) == {:ok, true}
    end

    test "same-category comparison validates as boolean", %{ctx: ctx} do
      assert Elex.validate("1m > 10cm", ctx) == {:ok, :boolean}
    end

    test "rejects comparing a unit and a dimensionless number", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m > 5", ctx)
      assert message == "cannot compare length and number"
    end

    test "rejects equality between a unit and a dimensionless number", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m == 1", ctx)
      assert message == "cannot compare length and number"
    end

    test "same-category equality validates as boolean", %{ctx: ctx} do
      assert Elex.validate("1m == 1m", ctx) == {:ok, :boolean}
      assert Elex.validate("1m == 1000mm", ctx) == {:ok, :boolean}
    end

    test "same-category equality converts into the left unit", %{ctx: ctx} do
      assert Elex.evaluate("1m == 1000mm", ctx) == {:ok, true}
    end

    test "same-category inequality converts into the left unit", %{ctx: ctx} do
      assert Elex.evaluate("1m != 1mm", ctx) == {:ok, true}
    end

    test "same-category less-than converts into the left unit", %{ctx: ctx} do
      assert Elex.evaluate("1m < 10cm", ctx) == {:ok, false}
      assert Elex.evaluate("1cm < 1m", ctx) == {:ok, true}
    end

    test "same-category less-or-equal converts into the left unit", %{ctx: ctx} do
      assert Elex.evaluate("1m <= 100cm", ctx) == {:ok, true}
      assert Elex.evaluate("1m <= 99cm", ctx) == {:ok, false}
    end

    test "same-category greater-or-equal converts into the left unit", %{ctx: ctx} do
      assert Elex.evaluate("1m >= 100cm", ctx) == {:ok, true}
      assert Elex.evaluate("99cm >= 1m", ctx) == {:ok, false}
    end
  end

  describe "comparisons with literal zero" do
    test "validates comparing a quantity to literal 0 as boolean", %{ctx: ctx} do
      assert Elex.validate("10cm > 0", ctx) == {:ok, :boolean}
    end

    test "evaluates 10cm greater than 0 as true", %{ctx: ctx} do
      assert Elex.evaluate("10cm > 0", ctx) == {:ok, true}
    end

    test "evaluates 10cm equal to 0 as false", %{ctx: ctx} do
      assert Elex.evaluate("10cm == 0", ctx) == {:ok, false}
    end

    test "evaluates 10cm less than 0 as false", %{ctx: ctx} do
      assert Elex.evaluate("10cm < 0", ctx) == {:ok, false}
    end

    test "evaluates 0 less than 10cm as true", %{ctx: ctx} do
      assert Elex.evaluate("0 < 10cm", ctx) == {:ok, true}
    end

    test "evaluates 0cm equal to 0 as true", %{ctx: ctx} do
      assert Elex.evaluate("0cm == 0", ctx) == {:ok, true}
    end

    test "treats 0.0 as literal 0", %{ctx: ctx} do
      assert Elex.evaluate("10cm > 0.0", ctx) == {:ok, true}
    end

    test "treats -0 as literal 0", %{ctx: ctx} do
      assert Elex.evaluate("10cm > -0", ctx) == {:ok, true}
    end

    test "evaluates <= >= and != against literal 0", %{ctx: ctx} do
      assert Elex.evaluate("10cm >= 0", ctx) == {:ok, true}
      assert Elex.evaluate("10cm <= 0", ctx) == {:ok, false}
      assert Elex.evaluate("10cm != 0", ctx) == {:ok, true}
    end

    test "rejects comparing a quantity to a non-zero number", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("10cm > 1", ctx)
      assert message == "cannot compare length and number"
    end

    test "rejects comparing a quantity to a computed zero", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("10cm > (1 - 1)", ctx)
      assert message == "cannot compare length and number"
    end

    test "rejects comparing a quantity to a number variable", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "count", 0)

      assert {:error, message} = Elex.validate("10cm > count", ctx)
      assert message == "cannot compare length and number"
    end
  end

  describe "between converts into the first argument's unit" do
    test "same-category between validates as boolean", %{ctx: ctx} do
      assert Elex.validate("between(50cm, 1m, 2m)", ctx) == {:ok, :boolean}
    end

    test "same-category between evaluates using first-arg conversion", %{ctx: ctx} do
      assert Elex.evaluate("between(50cm, 1m, 2m)", ctx) == {:ok, false}
      assert Elex.evaluate("between(150cm, 1m, 2m)", ctx) == {:ok, true}
    end

    test "rejects between of mixed categories", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("between(1m, 1kg, 2m)", ctx)
      assert message == "cannot mix length and mass"
    end
  end

  describe "restrict functions reject unit-bearing arguments" do
    test "sqrt of a unitful value is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("sqrt(4m)", ctx)
      assert message == "sqrt function expects a number argument, got length quantity"
    end

    test "sqrt of a leftover square is still an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("sqrt(1m * 1m)", ctx)
      assert message == "sqrt function expects a number argument, got length^2 quantity"
    end

    test "length of a quantity names the category as a quantity", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("length(1m)", ctx)
      assert message == "length function expects a string argument, got length quantity"
    end

    test "concat of a quantity names the category as a quantity", %{ctx: ctx} do
      assert {:error, message} = Elex.validate(~s[concat(1m)], ctx)
      assert message == "concat function expects string arguments, got length quantity"
    end

    test "upper of a quantity names the category as a quantity", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("upper(1m)", ctx)
      assert message == "upper function expects a string argument, got length quantity"
    end

    test "pow of a unitful value is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("pow(4m, 2)", ctx)
      assert message == "pow function expects number arguments, got length quantity"
    end
  end

  describe "remainder operators reject unit-bearing arguments" do
    test "rem of two quantities is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("rem(1m, 2m)", ctx)
      assert message == "rem function expects number arguments, got length quantity"
    end

    test "mod of two quantities is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("mod(1m, 2m)", ctx)
      assert message == "mod function expects number arguments, got length quantity"
    end

    test "% of two quantities is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m % 2m", ctx)
      assert message == "'%' operator expects number arguments, got length quantity"
    end

    test "rem of a quantity and a number is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("rem(1m, 2)", ctx)
      assert message == "rem function expects number arguments, got length quantity"
    end

    test "% of a quantity and a number is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m % 2", ctx)
      assert message == "'%' operator expects number arguments, got length quantity"
    end

    test "evaluate rejects rem of quantities", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("rem(1m, 2m)", ctx)
      assert message == "rem function expects number arguments, got length quantity"
    end

    test "mod of a number and a quantity is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("mod(1, 2m)", ctx)
      assert message == "mod function expects number arguments, got length quantity"
    end
  end

  describe "signature units:" do
    test "point builtins declare units: :point" do
      for module <- [
            Elex.Functions.Abs,
            Elex.Functions.Ceil,
            Elex.Functions.Floor,
            Elex.Functions.Round,
            Elex.Functions.Min,
            Elex.Functions.Max,
            Elex.Functions.Clamp,
            Elex.Functions.Between,
            Elex.Functions.If
          ] do
        assert Function.units(module) == :point, "#{inspect(module)} should be :point"
      end
    end

    test "none builtins declare units: :none" do
      for module <- [
            Elex.Functions.Sqrt,
            Elex.Functions.Pow,
            Elex.Functions.Rem,
            Elex.Functions.Mod,
            Elex.Functions.Concat,
            Elex.Functions.Length,
            Elex.Functions.Upper,
            Elex.Functions.Lower,
            Elex.Functions.Trim,
            Elex.Functions.StartsWith,
            Elex.Functions.EndsWith,
            Elex.Functions.Contains,
            Elex.Functions.Match
          ] do
        assert Function.units(module) == :none, "#{inspect(module)} should be :none"
      end
    end

    test "omitted units: defaults to :additive" do
      assert Function.units(%{name: :double, arity: 1}) == :additive
      assert Function.units(Double) == :additive
    end

    test "convert, add_unit, and remove_unit declare explicit units: policies" do
      assert Function.units(Elex.Functions.Convert) == :convert
      assert Function.units(Elex.Functions.AddUnit) == :wrap
      assert Function.units(Elex.Functions.RemoveUnit) == :unwrap
    end

    test "pi declares units: :none" do
      assert Function.units(Elex.Functions.Pi) == :none
    end

    test "coalesce declares units: :point" do
      assert Function.units(Elex.Functions.Coalesce) == :point
    end
  end

  describe "unmarked custom double is additive" do
    setup do
      catalog = Temperature.catalog()
      {:ok, catalog} = Catalog.add_category(catalog, :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "km", "value * 1000")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: Context.add_function(ctx, Double)}
    end

    test "double of a length keeps the unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("double(1m)", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end

    test "double of a temperature is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("double(1C)", ctx)
      assert message == "cannot use non-additive temperature with 'double'"
    end

    test "convert of Fahrenheit to Celsius still validates", %{ctx: ctx} do
      assert Elex.validate(~S|convert(32F, "C")|, ctx) ==
               {:ok, %Elex.Dimension{monomial: %{temperature: 1}}}
    end

    test "sqrt stays :none and rejects unitful args", %{ctx: ctx} do
      assert Function.units(Elex.Functions.Sqrt) == :none
      assert {:error, message} = Elex.validate("sqrt(4m)", ctx)
      assert message == "sqrt function expects a number argument, got length quantity"
    end

    test "min of mixed temperature units is an error", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("min(1C, 32F)", ctx)
      assert message == "cannot mix units of non-additive temperature"
      assert {:error, message} = Elex.evaluate("min(1C, 32F)", ctx)
      assert message == "cannot mix units of non-additive temperature"
    end

    test "min of lengths still converts into the first unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("min(1m, 1km)", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end
  end

  describe "units: :none is enforced for custom functions" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: Context.add_function(ctx, NonePassthrough)}
    end

    test "rejects a quantity even when validate/2 would accept it", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("nonefn(1m)", ctx)
      assert message == "nonefn function does not accept unitful arguments"
    end

    test "rejects a quantity at evaluate time even if validation is skipped", %{ctx: ctx} do
      {:ok, ast, _} = Elex.Parser.parse("nonefn(1m)", ctx, validate: false)

      assert {:error, message} = Elex.Evaluator.evaluate(ast, ctx)
      assert message == "nonefn function does not accept unitful arguments"
    end

    test "accepts a dimensionless number", %{ctx: ctx} do
      assert Elex.validate("nonefn(2)", ctx) == {:ok, :decimal}
      assert {:ok, result} = Elex.evaluate("nonefn(2)", ctx)
      assert Decimal.compare(result, Decimal.new("2")) == :eq
    end
  end
end
