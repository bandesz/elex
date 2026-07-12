if Code.ensure_loaded?(Ash.Resource.Validation) do
  defmodule Elex.AshValidationTest do
    use ExUnit.Case, async: true

    alias Elex.{AshValidation, Context}
    alias Ash.Error.Changes.InvalidAttribute

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
    end
  end
end
