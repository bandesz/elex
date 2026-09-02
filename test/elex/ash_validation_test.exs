if Code.ensure_loaded?(Ash.Resource.Validation) do
  defmodule Elex.AshValidationTest do
    use ExUnit.Case, async: true

    alias Elex.{AshValidation, Context}
    alias Elex.Units.Catalog
    alias Ash.Error.Changes.InvalidAttribute

    defp length_context do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      ctx
    end

    defp speed_context do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

      {:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s", "value")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      ctx
    end

    describe "init/1 option validation" do
      test "returns error when :attribute option is missing" do
        assert {:error, "the :attribute option is required"} =
                 AshValidation.init(context: Elex.new_context(), expected_type: :decimal)
      end

      test "returns error when :attribute option is not an atom" do
        assert {:error, "the :attribute option must be an atom"} =
                 AshValidation.init(
                   attribute: "not_atom",
                   context: Elex.new_context(),
                   expected_type: :decimal
                 )
      end

      test "returns error when :context option is missing" do
        assert {:error, "the :context option is required"} =
                 AshValidation.init(attribute: :expr, expected_type: :decimal)
      end

      test "returns error when :context option is not a Context struct" do
        assert {:error, "the :context option must be a Elex.Context struct"} =
                 AshValidation.init(
                   attribute: :expr,
                   context: %{},
                   expected_type: :decimal
                 )
      end

      test "returns error when :expected_type option is missing" do
        assert {:error, "the :expected_type option is required"} =
                 AshValidation.init(attribute: :expr, context: Elex.new_context())
      end

      test "returns error when :expected_type option is not an atom" do
        assert {:error, "the :expected_type option must be an atom"} =
                 AshValidation.init(
                   attribute: :expr,
                   context: Elex.new_context(),
                   expected_type: "decimal"
                 )
      end

      test "returns error when :add_value_type_from_attribute is not an atom" do
        assert {:error, "the :add_value_type_from_attribute option must be an atom"} =
                 AshValidation.init(
                   attribute: :expr,
                   context: Elex.new_context(),
                   expected_type: :decimal,
                   add_value_type_from_attribute: "not_atom"
                 )
      end

      test "succeeds with valid required options" do
        assert {:ok, opts} =
                 AshValidation.init(
                   attribute: :expr,
                   context: Elex.new_context(),
                   expected_type: :decimal
                 )

        assert Keyword.get(opts, :attribute) == :expr
        assert %Context{} = Keyword.get(opts, :context)
        assert Keyword.get(opts, :expected_type) == :decimal
      end

      test "succeeds with valid :add_value_type_from_attribute option" do
        assert {:ok, opts} =
                 AshValidation.init(
                   attribute: :expr,
                   context: Elex.new_context(),
                   expected_type: :decimal,
                   add_value_type_from_attribute: :value_type
                 )

        assert Keyword.get(opts, :add_value_type_from_attribute) == :value_type
      end

      test "succeeds when :add_value_type_from_attribute is nil" do
        assert {:ok, _opts} =
                 AshValidation.init(
                   attribute: :expr,
                   context: Elex.new_context(),
                   expected_type: :decimal,
                   add_value_type_from_attribute: nil
                 )
      end

      test "succeeds with a catalog category as :expected_type when units are attached" do
        assert {:ok, opts} =
                 AshValidation.init(
                   attribute: :expr,
                   context: length_context(),
                   expected_type: :length
                 )

        assert Keyword.get(opts, :expected_type) == :length
      end

      test "returns error when :expected_type is not a registered catalog category" do
        assert {:error, "the :expected_type :mass is not a registered category"} =
                 AshValidation.init(
                   attribute: :expr,
                   context: length_context(),
                   expected_type: :mass
                 )
      end

      test "succeeds with a primitive :expected_type when units are attached" do
        assert {:ok, opts} =
                 AshValidation.init(
                   attribute: :expr,
                   context: length_context(),
                   expected_type: :decimal
                 )

        assert Keyword.get(opts, :expected_type) == :decimal
      end

      test "returns error when :expected_type is a category and the context has no catalog" do
        assert {:error, "the :expected_type :length requires a units catalog on the context"} =
                 AshValidation.init(
                   attribute: :expr,
                   context: Elex.new_context(),
                   expected_type: :length
                 )
      end
    end

    describe "validate/3" do
      defp changeset(attrs) do
        %Ash.Changeset{attributes: Map.new(attrs), data: %{}}
      end

      defp opts(extra \\ []) do
        Keyword.merge(
          [attribute: :expr, context: Elex.new_context(), expected_type: :decimal],
          extra
        )
      end

      test "returns :ok when the expression matches the expected type" do
        changeset = changeset(%{expr: "1 + 2"})

        assert :ok = AshValidation.validate(changeset, opts(), %{})
      end

      test "returns InvalidAttribute error when the expression type is wrong" do
        changeset = changeset(%{expr: "1 > 2"})

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(changeset, opts(expected_type: :decimal), %{})

        assert error.field == :expr
        assert error.message =~ "must return decimal, but returns boolean"
        assert error.value == "1 > 2"
      end

      test "returns InvalidAttribute error with the parser message on parse/validation error" do
        changeset = changeset(%{expr: "unknown_var + 1"})

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(changeset, opts(), %{})

        assert error.field == :expr
        assert error.message =~ "variable 'unknown_var' does not exist"
        assert error.value == "unknown_var + 1"
      end

      test "returns :ok when there is no pending change on the attribute" do
        changeset = changeset(%{value_type: :decimal})

        assert :error = Ash.Changeset.fetch_change(changeset, :expr)
        assert :ok = AshValidation.validate(changeset, opts(), %{})
      end

      test "injects a 'value' variable using :add_value_type_from_attribute" do
        changeset = changeset(%{expr: "value + 1", value_type: :decimal})

        assert :ok =
                 AshValidation.validate(
                   changeset,
                   opts(
                     expected_type: :decimal,
                     add_value_type_from_attribute: :value_type
                   ),
                   %{}
                 )
      end

      test "'value' variable type comes from the referenced attribute" do
        changeset = changeset(%{expr: "value", value_type: :boolean})

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(
                   changeset,
                   opts(
                     expected_type: :decimal,
                     add_value_type_from_attribute: :value_type
                   ),
                   %{}
                 )

        assert error.message =~ "must return decimal, but returns boolean"
      end

      test "context struct is unchanged when :add_value_type_from_attribute is not set" do
        context = Elex.new_context()
        changeset = changeset(%{expr: "value + 1", value_type: :decimal})

        assert %Context{} = context

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(changeset, opts(context: context), %{})

        assert error.message =~ "variable 'value' does not exist"
      end

      test "accepts a same-category sum when :expected_type is the catalog category" do
        changeset = changeset(%{expr: "1mm + 2m"})

        assert :ok =
                 AshValidation.validate(
                   changeset,
                   opts(context: length_context(), expected_type: :length),
                   %{}
                 )
      end

      test "rejects a boolean comparison when :expected_type is a catalog category" do
        changeset = changeset(%{expr: "1mm > 0"})

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(
                   changeset,
                   opts(context: length_context(), expected_type: :length),
                   %{}
                 )

        assert error.field == :expr
        assert error.message =~ "cannot compare length and number"
        assert error.value == "1mm > 0"
      end

      test "surfaces validate's category: mismatch when a decimal is not length" do
        changeset = changeset(%{expr: "1 + 2"})

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(
                   changeset,
                   opts(context: length_context(), expected_type: :length),
                   %{}
                 )

        assert error.field == :expr
        assert error.message == "length was expected, got number"
        assert error.value == "1 + 2"
      end

      test "accepts a speed-compatible quotient when :expected_type is :speed" do
        changeset = changeset(%{expr: "1cm / 1s"})

        assert :ok =
                 AshValidation.validate(
                   changeset,
                   opts(context: speed_context(), expected_type: :speed),
                   %{}
                 )
      end

      test "rejects a length product when :expected_type is :speed" do
        changeset = changeset(%{expr: "1m * 1m"})

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(
                   changeset,
                   opts(context: speed_context(), expected_type: :speed),
                   %{}
                 )

        assert error.message == "speed was expected, got length^2"
      end

      test "does not treat :length as the result type when the context has no catalog" do
        changeset = changeset(%{expr: "1 + 2"})

        assert {:error, %InvalidAttribute{} = error} =
                 AshValidation.validate(changeset, opts(expected_type: :length), %{})

        assert error.field == :expr
        assert error.message =~ "must return length, but returns decimal"
      end
    end
  end
end
