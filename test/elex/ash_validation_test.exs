if Code.ensure_loaded?(Ash.Resource.Validation) do
  defmodule Elex.AshValidationTest do
    use ExUnit.Case, async: true

    alias Elex.{AshValidation, Context}

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
  end
end
