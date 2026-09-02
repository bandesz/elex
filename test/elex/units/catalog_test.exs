defmodule Elex.Units.CatalogTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog

  describe "new/0" do
    test "returns an empty catalog" do
      catalog = Catalog.new()

      assert Catalog.categories(catalog) == %{}
    end
  end

  describe "add_category/3" do
    test "registers a base category with a default unit name" do
      catalog = Catalog.new()

      assert {:ok, catalog} = Catalog.add_category(catalog, :length, default: "m")
      assert Catalog.categories(catalog) == %{length: "m"}
    end

    test "registers multiple categories" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")

      assert Catalog.categories(catalog) == %{length: "m", mass: "kg"}
    end

    test "rejects a duplicate category name" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

      assert {:error, message} = Catalog.add_category(catalog, :length, default: "ft")
      assert message == "category :length already exists"
      assert catalog.categories[:length].default == "m"
      assert Map.has_key?(catalog.categories[:length].units, "m")
    end

    test "stores additive: false" do
      {:ok, catalog} =
        Catalog.add_category(Catalog.new(), :temperature, default: "C", additive: false)

      assert catalog.categories[:temperature].additive == false
    end

    test "defaults additive to true when omitted" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert catalog.categories[:length].additive == true
    end

    test "returns an error when a base category omits default" do
      assert {:error, message} = Catalog.add_category(Catalog.new(), :length, [])
      assert message =~ "default"
    end

    test "rejects identity: on a base category" do
      catalog = Catalog.new()

      assert {:error, message} =
               Catalog.add_category(catalog, :length, default: "m", identity: "m")

      assert message == "identity: is not allowed on base category :length"
      refute Map.has_key?(Catalog.categories(catalog), :length)
    end
  end

  describe "add_category!/3" do
    test "returns the catalog on success" do
      catalog = Catalog.add_category!(Catalog.new(), :length, default: "m")

      assert Catalog.categories(catalog) == %{length: "m"}
    end

    test "raises on a duplicate category name" do
      catalog = Catalog.add_category!(Catalog.new(), :length, default: "m")

      assert_raise ArgumentError, "category :length already exists", fn ->
        Catalog.add_category!(catalog, :length, default: "ft")
      end
    end

    test "raises when derived registration fails" do
      assert_raise ArgumentError, ~r/unknown category :/, fn ->
        Catalog.add_category!(Catalog.new(), :force,
          formula: "mass * length | time * time",
          default: "N"
        )
      end
    end
  end

  describe "add_unit/3" do
    test "registers identity conversion when to_default is omitted" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:ok, catalog} = Catalog.add_unit(catalog, :length, "m")

      unit = catalog.categories[:length].units["m"]
      assert unit.to_default == "value"
      assert unit.to_default_ast == {:var, "value"}
      assert unit.from_default_ast == {:var, "value"}
    end

    test "accepts aliases without a conversion string" do
      catalog = area_catalog()

      assert {:ok, catalog} = Catalog.add_unit(catalog, :area, "m^2", aliases: ["m2"])

      unit = catalog.categories[:area].units["m^2"]
      assert unit.to_default == "value"
      assert Catalog.category_for_unit(catalog, "m2") == {:ok, :area}
      assert Catalog.category_for_unit(catalog, "m^2") == {:ok, :area}
    end
  end

  describe "add_unit/4" do
    test "stores an invertible conversion to the category default" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")

      unit = catalog.categories[:length].units["mm"]
      assert unit.to_default == "value / 1000"
      assert {:ok, inverse} = Elex.Inverter.invert(unit.to_default_ast, "value")
      assert unit.from_default_ast == inverse
    end

    test "stores identity conversion for the default unit" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

      unit = catalog.categories[:length].units["m"]
      assert unit.to_default == "value"
      assert unit.to_default_ast == {:var, "value"}
      assert unit.from_default_ast == {:var, "value"}
    end

    test "inverts affine conversions" do
      {:ok, catalog} =
        Catalog.add_category(Catalog.new(), :temperature, default: "C", additive: false)

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :temperature, "F", "(value - 32) * 5 / 9")

      unit = catalog.categories[:temperature].units["F"]
      assert unit.to_default == "(value - 32) * 5 / 9"
      assert {:ok, inverse} = Elex.Inverter.invert(unit.to_default_ast, "value")
      assert unit.from_default_ast == inverse
    end

    test "rejects an offset conversion on an additive category" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :temperature, default: "C")

      assert {:error, message} =
               Catalog.add_unit(catalog, :temperature, "F", "(value - 32) * 5 / 9")

      assert message =~ "offset"
      assert catalog.categories[:temperature].units == %{}
    end

    test "rejects a charlist conversion instead of a string" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "mm", ~c"value / 1000")
      assert message == "conversion must be a string"
    end

    test "rejects a formula unit whose conversion disagrees with its components" do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m")
        |> Catalog.add_unit!(:length, "cm", "value / 100")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2")

      assert {:error, message} = Catalog.add_unit(catalog, :area, "cm^2", "value / 5000")

      assert message ==
               "unit 'cm^2' conversion does not match the scale of its component units"
    end

    test "accepts a formula unit whose conversion matches its components" do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m")
        |> Catalog.add_unit!(:length, "cm", "value / 100")
        |> Catalog.add_category!(:area, formula: "length * length", default: "m^2")
        |> Catalog.add_unit!(:area, "m^2")

      assert {:ok, catalog} = Catalog.add_unit(catalog, :area, "cm^2", "value / 10000")
      assert {:ok, _} = Catalog.fetch_unit(catalog, "cm^2")
    end

    test "rejects a non-invertible conversion" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "mm", "abs(value)")
      assert message =~ "inversion"
      assert catalog.categories[:length].units == %{}
    end

    test "rejects a comparison expression" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "mm", "value > 0")
      assert message =~ "numeric"
      assert catalog.categories[:length].units == %{}
    end

    test "rejects an expression with another variable" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "mm", "value + x")
      assert message =~ "variable"
      assert catalog.categories[:length].units == %{}
    end

    test "rejects a non-numeric expression" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "mm", "true")
      assert message =~ "numeric"
      assert catalog.categories[:length].units == %{}
    end

    test "rejects an unknown category without mutating the catalog" do
      catalog = Catalog.new()

      assert {:error, message} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      assert message =~ "unknown category"
      assert Catalog.categories(catalog) == %{}
    end

    test "accepts names with letters, digits, and underscore" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:ok, catalog} = Catalog.add_unit(catalog, :length, "m2", "value")
      assert {:ok, catalog} = Catalog.add_unit(catalog, :length, "N", "value")
      assert {:ok, catalog} = Catalog.add_unit(catalog, :length, "foo_bar", "value")

      assert Map.has_key?(catalog.categories[:length].units, "m2")
      assert Map.has_key?(catalog.categories[:length].units, "N")
      assert Map.has_key?(catalog.categories[:length].units, "foo_bar")
    end

    test "rejects a name that does not start with a letter" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "2m", "value")
      assert message =~ "2m"
      assert catalog.categories[:length].units == %{}

      assert {:error, _} = Catalog.add_unit(catalog, :length, "_mm", "value")
    end

    test "rejects a name with characters other than letters, digits, and underscore" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "m-m", "value")
      assert message =~ "m-m"
      assert catalog.categories[:length].units == %{}
    end

    test "rejects reserved words as unit names" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      reserved = ["and", "or", "not", "null", "true", "false", "yes", "no", "e", "E"]

      for keyword <- reserved do
        assert {:error, message} = Catalog.add_unit(catalog, :length, keyword, "value")
        assert message =~ "reserved"
        assert catalog.categories[:length].units == %{}
      end
    end

    test "rejects a duplicate unit name in the same category" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")

      assert {:error, message} = Catalog.add_unit(catalog, :length, "mm", "value / 100")
      assert message =~ "mm"
      assert catalog.categories[:length].units["mm"].to_default == "value / 1000"
    end

    test "rejects a duplicate unit name in another category" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "x", "value")

      assert {:error, message} = Catalog.add_unit(catalog, :mass, "x", "value")
      assert message =~ "x"
      assert catalog.categories[:mass].units == %{}
    end
  end

  describe "add_unit aliases" do
    test "registers aliases that resolve to the same category" do
      catalog = area_catalog()

      assert {:ok, catalog} =
               Catalog.add_unit(catalog, :area, "m^2", "value", aliases: ["m2", "sqm"])

      assert Catalog.category_for_unit(catalog, "m2") == {:ok, :area}
      assert Catalog.category_for_unit(catalog, "sqm") == {:ok, :area}
      assert Catalog.category_for_unit(catalog, "m^2") == {:ok, :area}
    end

    test "add_unit/4 registers a unit with an explicit conversion" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      assert Catalog.category_for_unit(catalog, "m") == {:ok, :length}
    end

    test "rejects an alias that collides with a unit name" do
      catalog = area_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value")

      assert {:error, message} =
               Catalog.add_unit(catalog, :area, "m^2", "value", aliases: ["m2"])

      assert message =~ "m2"
      refute Map.has_key?(catalog.categories[:area].units, "m^2")
    end

    test "rejects a duplicate alias" do
      catalog = area_catalog()

      {:ok, catalog} =
        Catalog.add_unit(catalog, :area, "m^2", "value", aliases: ["m2", "sqm"])

      assert {:error, message} =
               Catalog.add_unit(catalog, :area, "ha", "value * 10000", aliases: ["m2"])

      assert message =~ "m2"
      refute Map.has_key?(catalog.categories[:area].units, "ha")
    end

    test "rejects a unit name that collides with an alias" do
      catalog = area_catalog()

      {:ok, catalog} =
        Catalog.add_unit(catalog, :area, "m^2", "value", aliases: ["m2"])

      assert {:error, message} = Catalog.add_unit(catalog, :area, "m2", "value")
      assert message =~ "m2"
      refute Map.has_key?(catalog.categories[:area].units, "m2")
    end

    test "rejects an alias that is not a symbol" do
      catalog = area_catalog()

      assert {:error, message} =
               Catalog.add_unit(catalog, :area, "m^2", "value", aliases: ["m^2"])

      assert message =~ "m^2"
      refute Map.has_key?(catalog.categories[:area].units, "m^2")
    end

    test "validate and put_units reject a default that is an alias" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m2")

      {:ok, catalog} =
        Catalog.add_unit(catalog, :area, "m^2", "value", aliases: ["m2"])

      assert {:error, message} = Catalog.validate(catalog)
      assert message == "default 'm2' is not among the units of :area"

      assert {:error, ^message} = Context.put_units(Elex.new_context(), catalog)
    end
  end

  describe "add_unit!/4" do
    test "returns the catalog on success" do
      catalog = Catalog.add_category!(Catalog.new(), :length, default: "m")
      catalog = Catalog.add_unit!(catalog, :length, "mm", "value / 1000")

      assert {:ok, unit} = Catalog.fetch_unit(catalog, "mm")
      assert unit.to_default == "value / 1000"
    end

    test "registers identity conversion when to_default is omitted" do
      catalog = Catalog.add_category!(Catalog.new(), :length, default: "m")
      catalog = Catalog.add_unit!(catalog, :length, "m")

      assert {:ok, unit} = Catalog.fetch_unit(catalog, "m")
      assert unit.to_default == "value"
    end

    test "accepts aliases without a conversion string" do
      catalog = Catalog.add_unit!(area_catalog(), :area, "m^2", aliases: ["m2"])

      assert {:ok, unit} = Catalog.fetch_unit(catalog, "m^2")
      assert unit.to_default == "value"
      assert Catalog.category_for_unit(catalog, "m2") == {:ok, :area}
      assert Catalog.fetch_unit(catalog, "m2") == Catalog.fetch_unit(catalog, "m^2")
    end

    test "raises when the conversion is a charlist" do
      catalog = Catalog.add_category!(Catalog.new(), :length, default: "m")

      assert_raise ArgumentError, "conversion must be a string", fn ->
        Catalog.add_unit!(catalog, :length, "mm", ~c"value / 1000")
      end
    end

    test "raises on an unknown category" do
      assert_raise ArgumentError, "unknown category :length", fn ->
        Catalog.add_unit!(Catalog.new(), :length, "mm", "value / 1000")
      end
    end
  end

  describe "parse_formula/2" do
    setup do
      catalog =
        Catalog.new()
        |> Catalog.add_category!(:length, default: "m")
        |> Catalog.add_unit!(:length, "m", "value")
        |> Catalog.add_unit!(:length, "mm", "value / 1000")
        |> Catalog.add_category!(:time, default: "s")
        |> Catalog.add_unit!(:time, "s", "value")

      %{catalog: catalog}
    end

    test "parses a compound formula", %{catalog: catalog} do
      assert Catalog.parse_formula(catalog, "m | s") == {:ok, %{"m" => 1, "s" => -1}}
    end

    test "rejects a cancelled formula", %{catalog: catalog} do
      assert Catalog.parse_formula(catalog, "m | m") == {:error, "invalid formula 'm | m'"}
    end

    test "rejects a zero exponent", %{catalog: catalog} do
      assert Catalog.parse_formula(catalog, "m^0") == {:error, "invalid formula 'm^0'"}
    end

    test "rejects the same category in numerator and denominator", %{catalog: catalog} do
      assert Catalog.parse_formula(catalog, "m | mm") ==
               {:error,
                "formula 'm | mm' repeats category :length in the numerator and denominator"}
    end

    test "rejects an unknown symbol", %{catalog: catalog} do
      assert Catalog.parse_formula(catalog, "m | foo") == {:error, "unknown unit 'foo'"}
    end
  end

  describe "parse_formula/2 derived identity cancel" do
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

      %{catalog: catalog}
    end

    test "rejects a derived unit over its identity formula", %{catalog: catalog} do
      assert Catalog.parse_formula(catalog, "ha | m^2") ==
               {:error,
                "formula 'ha | m^2' repeats category :length in the numerator and denominator"}

      assert Catalog.parse_formula(catalog, "N * s^2 | kg * m") ==
               {:error,
                "formula 'N * s^2 | kg * m' repeats category :length in the numerator and denominator"}
    end

    test "still accepts a derived unit over a different category", %{catalog: catalog} do
      assert Catalog.parse_formula(catalog, "N | s") == {:ok, %{"N" => 1, "s" => -1}}

      assert Catalog.parse_formula(catalog, "kg * m | s^2") ==
               {:ok, %{"kg" => 1, "m" => 1, "s" => -2}}
    end
  end

  describe "kind/2" do
    test "returns :base for a category without formula" do
      catalog = Catalog.add_category!(Catalog.new(), :length, default: "m")

      assert Catalog.kind(catalog, :length) == {:ok, :base}
    end

    test "returns :derived for a category with formula" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m2")

      assert Catalog.kind(catalog, :area) == {:ok, :derived}
    end

    test "returns :error for an unknown category" do
      assert Catalog.kind(Catalog.new(), :length) == :error
    end
  end

  describe "category_for_unit/2" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")

      %{catalog: catalog}
    end

    test "returns the category for a registered unit", %{catalog: catalog} do
      assert Catalog.category_for_unit(catalog, "mm") == {:ok, :length}
      assert Catalog.category_for_unit(catalog, "m") == {:ok, :length}
      assert Catalog.category_for_unit(catalog, "kg") == {:ok, :mass}
    end

    test "returns :error for an unregistered unit", %{catalog: catalog} do
      assert Catalog.category_for_unit(catalog, "cm") == :error
    end
  end

  describe "derived categories" do
    test "registers a derived category with a formula and default hub" do
      catalog = base_catalog()

      assert {:ok, catalog} =
               Catalog.add_category(catalog, :force,
                 formula: "mass * length | time * time",
                 default: "N"
               )

      assert Catalog.categories(catalog).force == "N"
    end

    test "rejects a derived category without default" do
      catalog = base_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :force, formula: "mass * length | time * time")

      assert message == "derived category :force requires default:"
      refute Map.has_key?(Catalog.categories(catalog), :force)
    end

    test "rejects default_result_unit in favor of default" do
      catalog = base_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :force,
                 formula: "mass * length | time * time",
                 default_result_unit: "N"
               )

      assert message =~ "default:"
      refute Map.has_key?(Catalog.categories(catalog), :force)
    end

    test "rejects a duplicate derived category name" do
      catalog = force_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :force,
                 formula: "mass * length | time * time",
                 default: "N"
               )

      assert message == "category :force already exists"
    end

    test "rejects a derived category with the same dimension as another derived category" do
      catalog = force_catalog()
      energy = "mass * length * length | time * time"

      {:ok, catalog} = Catalog.add_category(catalog, :energy, formula: energy, default: "J")

      assert {:error, message} =
               Catalog.add_category(catalog, :torque, formula: energy, default: "N_m")

      assert message =~ ":energy"
      assert message =~ ":torque"
      refute Map.has_key?(Catalog.categories(catalog), :torque)
    end

    test "rejects a derived category whose dimension matches a base category" do
      catalog = base_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :distance, formula: "length", default: "m")

      assert message =~ ":length"
      assert message =~ ":distance"
      refute Map.has_key?(Catalog.categories(catalog), :distance)
    end

    test "registers derived categories with distinct dimensions" do
      catalog = force_catalog()

      assert {:ok, catalog} =
               Catalog.add_category(catalog, :energy,
                 formula: "mass * length * length | time * time",
                 default: "J"
               )

      assert {:ok, catalog} =
               Catalog.add_category(catalog, :area, formula: "length * length", default: "m * m")

      assert Map.has_key?(Catalog.categories(catalog), :force)
      assert Map.has_key?(Catalog.categories(catalog), :energy)
      assert Map.has_key?(Catalog.categories(catalog), :area)
    end

    test "registers a named unit and a formula unit with identity conversion" do
      catalog = force_catalog()

      assert {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")
      assert {:ok, catalog} = Catalog.add_unit(catalog, :force, "kg * m | s^2", "value")

      newton = catalog.categories[:force].units["N"]
      assert newton.to_default == "value"
      assert newton.to_default_ast == {:var, "value"}
      assert newton.from_default_ast == {:var, "value"}

      formula = catalog.categories[:force].units["kg * m | s^2"]
      assert formula.to_default == "value"
      assert formula.to_default_ast == {:var, "value"}
      assert formula.from_default_ast == {:var, "value"}
    end

    test "rejects a formula unit whose dimension does not match the category" do
      catalog = force_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")

      assert {:error, message} = Catalog.add_unit(catalog, :force, "m * m", "value")
      assert message =~ "dimension"
      refute Map.has_key?(catalog.categories[:force].units, "m * m")
    end

    test "rejects a formula unit that repeats a category in numerator and denominator" do
      catalog = force_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")

      assert {:error, message} = Catalog.add_unit(catalog, :force, "N * s | s", "value")

      assert message ==
               "formula 'N * s | s' repeats category :time in the numerator and denominator"

      refute Map.has_key?(catalog.categories[:force].units, "N * s | s")
    end

    test "rejects a formula unit that repeats a category with different units" do
      catalog = force_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "hour", "value * 3600")

      assert {:error, message} = Catalog.add_unit(catalog, :force, "N * s | hour", "value")

      assert message ==
               "formula 'N * s | hour' repeats category :time in the numerator and denominator"

      refute Map.has_key?(catalog.categories[:force].units, "N * s | hour")
    end

    test "formula_identity/2 is the base-hub product, not another compound unit" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "km", "value * 1000")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m2")

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "km * km", "value * 1000000")
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

      assert Catalog.formula_identity(catalog, :area) == {"m * m", %{"m" => 2}}
    end

    test "formula_identity/2 returns identity: even when no unit has that name" do
      catalog = force_catalog_with_identity()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N")

      assert Catalog.formula_identity(catalog, :force) ==
               {"kg * m | s^2", %{"kg" => 1, "m" => 1, "s" => -2}}
    end

    test "formula_identity/2 uses a registered unit whose name parses to identity:" do
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

      assert Catalog.formula_identity(catalog, :area) == {"m * m", %{"m" => 2}}
    end

    test "rejects a formula unit with an unknown component" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :force,
          formula: "mass * length | time * time",
          default: "N"
        )

      assert {:error, message} = Catalog.add_unit(catalog, :force, "kg * m | s^2", "value")
      assert message =~ "kg"
      refute Map.has_key?(catalog.categories[:force].units, "kg * m | s^2")
    end

    test "rejects a derived formula that references an unknown category" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} =
               Catalog.add_category(catalog, :force,
                 formula: "mass * length | time * time",
                 default: "N"
               )

      assert message =~ "mass"
      refute Map.has_key?(Catalog.categories(catalog), :force)
    end

    test "rejects a derived formula that references a derived category" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")

      assert {:error, message} =
               Catalog.add_category(catalog, :acceleration,
                 formula: "speed | time",
                 default: "m | s^2"
               )

      assert message == "formula may only use base categories; :speed is derived"
      refute Map.has_key?(Catalog.categories(catalog), :acceleration)
    end

    test "validate rejects a default hub that is not among the category units" do
      catalog = force_catalog()

      assert {:error, message} = Catalog.validate(catalog)
      assert message == "default 'N' is not among the units of :force"
    end

    test "validate rejects a derived category whose hub is registered but identity is missing" do
      catalog = force_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")

      assert {:error, message} = Catalog.validate(catalog)

      assert message ==
               ~s[derived category :force needs a registered unit matching the base hubs (e.g. "kg * m | s * s")]
    end

    test "validate rejects :area with m2 but no unit matching the base-hub product" do
      catalog = area_catalog_without_identity()

      assert {:error, message} = Catalog.validate(catalog)

      assert message ==
               ~s[derived category :area needs a registered unit matching the base hubs (e.g. "m * m")]
    end

    test "validate accepts :area when the identity is registered as m * m" do
      catalog = area_catalog_without_identity()
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

      assert Catalog.validate(catalog) == :ok
    end

    test "validate accepts :area when the identity is registered as m^2" do
      catalog = area_catalog_without_identity()
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m^2", "value")

      assert Catalog.validate(catalog) == :ok
    end

    test "validate accepts :force once the hub and kg * m | s^2 identity are registered" do
      catalog = force_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "kg * m | s^2", "value")

      assert Catalog.validate(catalog) == :ok
    end

    test "validate rejects a base default that is not among the category units" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Catalog.validate(catalog)
      assert message == "default 'm' is not among the units of :length"
    end

    test "put_units rejects a base default that is not among the category units" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert {:error, message} = Context.put_units(Elex.new_context(), catalog)
      assert message == "default 'm' is not among the units of :length"
    end

    test "put_units rejects a derived default that is not among the category units" do
      assert {:error, message} = Context.put_units(Elex.new_context(), force_catalog())
      assert message == "default 'N' is not among the units of :force"
    end

    test "put_units rejects :area with m2 but no base-hub identity" do
      catalog = area_catalog_without_identity()

      assert {:error, message} = Context.put_units(Elex.new_context(), catalog)

      assert message ==
               ~s[derived category :area needs a registered unit matching the base hubs (e.g. "m * m")]
    end

    test "put_units attaches :area after the identity is registered" do
      catalog = area_catalog_without_identity()
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

      assert {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      assert Catalog.kind(ctx.units, :area) == {:ok, :derived}
    end

    test "put_units attaches :force with kg * m | s^2 identity" do
      catalog = force_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "kg * m | s^2", "value")

      assert {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      assert ctx.units == catalog
    end

    test "put_units rejects :force with identity: and only unit N" do
      catalog = force_catalog_with_identity()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N")

      assert catalog.categories[:force].identity == "kg * m | s^2"
      assert {:error, message} = Catalog.validate(catalog)

      assert message ==
               ~s[derived category :force needs a registered unit matching the base hubs (e.g. "kg * m | s * s")]

      assert {:error, ^message} = Context.put_units(Elex.new_context(), catalog)
    end

    test "put_units attaches :force with identity: when the identity unit is registered" do
      catalog = force_catalog_with_identity()
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "N")
      {:ok, catalog} = Catalog.add_unit(catalog, :force, "kg * m | s^2")

      assert catalog.categories[:force].identity == "kg * m | s^2"
      assert Catalog.validate(catalog) == :ok
      assert {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      assert Map.has_key?(ctx.units.categories[:force].units, "kg * m | s^2")
    end

    test "rejects identity: that does not match the base-hub product" do
      catalog = base_catalog()

      assert {:error, message} =
               Catalog.add_category(catalog, :force,
                 formula: "mass * length | time * time",
                 default: "N",
                 identity: "m^2"
               )

      assert message == "identity 'm^2' does not match the base-hub product of :force"
      refute Map.has_key?(Catalog.categories(catalog), :force)
    end

    test "put_units attaches :area when default: is m^2 without identity:" do
      catalog = area_catalog()
      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m^2", aliases: ["m2", "sqm"])

      assert {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      refute Map.has_key?(ctx.units.categories[:area], :identity)
      assert Catalog.category_for_unit(ctx.units, "m2") == {:ok, :area}
      assert Catalog.category_for_unit(ctx.units, "sqm") == {:ok, :area}
    end

    test "put_units attaches :area with ha hub, identity: m^2, and scaled m^2 unit" do
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

      assert {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      assert ctx.units.categories[:area].identity == "m^2"
      assert ctx.units.categories[:area].default == "ha"
    end

    test "put_units rejects :area with identity: when the identity unit is missing" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area,
          formula: "length * length",
          default: "ha",
          identity: "m^2"
        )

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "ha")

      assert {:error, message} = Context.put_units(Elex.new_context(), catalog)

      assert message ==
               ~s[derived category :area needs a registered unit matching the base hubs (e.g. "m * m")]
    end

    test "put_units! raises when a derived category has no identity" do
      catalog = area_catalog_without_identity()

      assert_raise ArgumentError,
                   ~s[derived category :area needs a registered unit matching the base hubs (e.g. "m * m")],
                   fn ->
                     Context.put_units!(Elex.new_context(), catalog)
                   end
    end
  end

  defp base_catalog do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
    {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")
    {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
    {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")
    catalog
  end

  defp force_catalog do
    {:ok, catalog} =
      Catalog.add_category(base_catalog(), :force,
        formula: "mass * length | time * time",
        default: "N"
      )

    catalog
  end

  defp force_catalog_with_identity do
    {:ok, catalog} =
      Catalog.add_category(base_catalog(), :force,
        formula: "mass * length | time^2",
        default: "N",
        identity: "kg * m | s^2"
      )

    catalog
  end

  defp area_catalog do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :area, formula: "length * length", default: "m^2")

    catalog
  end

  defp area_catalog_without_identity do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")

    {:ok, catalog} =
      Catalog.add_category(catalog, :area, formula: "length * length", default: "m2")

    {:ok, catalog} = Catalog.add_unit(catalog, :area, "m2", "value")
    catalog
  end
end
