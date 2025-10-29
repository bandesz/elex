if Code.ensure_loaded?(Ash.Resource.Validation) do
  defmodule Elex.AshValidation do
    @moduledoc """
    Validates an Elex Expression string in Ash resources.

    Options:
    * `:attribute`: The name of the attribute which contains the expression
    * `:context`: A `Elex.Context` struct defining the allowed variables and functions.
    * `:expected_type`: The expected result type (atom) of the expression (e.g., `:boolean`, `:decimal`).
    * `:add_value_type_from_attribute`: It adds a `value` variable to the context with the type defined by this attribute.
    """
    use Ash.Resource.Validation
    alias Ash.Error.Changes.InvalidAttribute

    @impl true
    def init(opts) do
      with {:ok, _} <- validate_attribute_option(opts),
           {:ok, _} <- validate_context_option(opts),
           {:ok, _} <- validate_expected_type_option(opts),
           {:ok, _} <- validate_add_value_type_option(opts) do
        {:ok, opts}
      end
    end

    defp validate_attribute_option(opts) do
      case Keyword.get(opts, :attribute) do
        nil -> {:error, "the :attribute option is required"}
        attr when is_atom(attr) -> {:ok, attr}
        _ -> {:error, "the :attribute option must be an atom"}
      end
    end

    defp validate_context_option(opts) do
      case Keyword.get(opts, :context) do
        nil -> {:error, "the :context option is required"}
        %Elex.Context{} = ctx -> {:ok, ctx}
        _ -> {:error, "the :context option must be a Elex.Context struct"}
      end
    end

    defp validate_expected_type_option(opts) do
      case Keyword.get(opts, :expected_type) do
        nil -> {:error, "the :expected_type option is required"}
        type when is_atom(type) -> {:ok, type}
        _ -> {:error, "the :expected_type option must be an atom"}
      end
    end

    defp validate_add_value_type_option(opts) do
      case Keyword.get(opts, :add_value_type_from_attribute) do
        nil -> {:ok, nil}
        attr when is_atom(attr) -> {:ok, attr}
        _ -> {:error, "the :add_value_type_from_attribute option must be an atom"}
      end
    end

    alias Elex.Parser
    alias Elex.Variable

    @impl true
    def validate(changeset, opts, _context) do
      attribute = Keyword.fetch!(opts, :attribute)
      context = Keyword.fetch!(opts, :context)
      expected_type = Keyword.fetch!(opts, :expected_type)
      add_value_type_from_attribute = Keyword.get(opts, :add_value_type_from_attribute)

      context =
        if add_value_type_from_attribute do
          type = Ash.Changeset.get_attribute(changeset, add_value_type_from_attribute)

          Elex.Context.add_variable(context, "value", %Variable{type: type})
        else
          context
        end

      case Ash.Changeset.fetch_change(changeset, attribute) do
        {:ok, expression_string} when is_binary(expression_string) ->
          case Parser.parse(expression_string, context) do
            {:ok, _ast, ^expected_type} ->
              :ok

            {:ok, _ast, actual_type} ->
              {:error,
               [
                 field: attribute,
                 message: "must return #{expected_type}, but returns #{actual_type}",
                 value: expression_string
               ]
               |> with_description(opts)
               |> InvalidAttribute.exception()}

            {:error, reason} ->
              {:error,
               [
                 field: attribute,
                 message: reason,
                 value: expression_string
               ]
               |> with_description(opts)
               |> InvalidAttribute.exception()}
          end

        _ ->
          :ok
      end
    end
  end
end
