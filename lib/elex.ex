defmodule Elex do
  @moduledoc """
  Elex is an expression language library for parsing, validating, and evaluating expressions.

  It supports:
  - Arithmetic operations (+, -, *, /)
  - Comparison operators (<, >, <=, >=, ==, !=)
  - Boolean operations (and, or, not)
  - Variables
  - Functions
  - Type checking and validation
  """

  alias Elex.Context

  @standard_functions [
    Elex.Functions.Ceil,
    Elex.Functions.Floor,
    Elex.Functions.If,
    Elex.Functions.Max,
    Elex.Functions.Min,
    Elex.Functions.Pi,
    Elex.Functions.Rem,
    Elex.Functions.Round,
    Elex.Functions.Sqrt
  ]

  @spec new_context(map()) :: Context.t()
  def new_context(variables \\ %{}) when is_map(variables) do
    # Start with empty context and add all standard functions using the proper method
    context = %Context{variables: variables}

    Enum.reduce(@standard_functions, context, fn module, acc ->
      Context.add_function(acc, module)
    end)
  end

  @spec evaluate(String.t(), Context.t()) :: {:ok, any()} | {:error, String.t()}
  def evaluate(expression_string, context) do
    with {:ok, ast, _type} <- Elex.Parser.parse(expression_string, context),
         result <- Elex.Evaluator.evaluate(ast, context) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    e in RuntimeError -> {:error, "Evaluation error: #{e.message}"}
  end

  @spec validate(String.t(), Context.t()) :: {:ok, atom()} | {:error, String.t()}
  def validate(expression_string, context) do
    Elex.Parser.parse(expression_string, context)
    |> case do
      {:ok, _ast, type} -> {:ok, type}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec extract_variables(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def extract_variables(expression_string) do
    case Elex.Parser.parse(expression_string, %Context{}, validate: false) do
      {:ok, ast, _type} ->
        variables = extract_variables_from_ast(ast)
        {:ok, variables}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_variables_from_ast(ast) do
    ast
    |> do_extract_variables()
    |> Enum.uniq()
  end

  defp do_extract_variables({:var, variable_name}) when is_binary(variable_name) do
    [variable_name]
  end

  defp do_extract_variables({:func, _name, _arity, args}) when is_list(args) do
    Enum.flat_map(args, &do_extract_variables/1)
  end

  defp do_extract_variables({operator, operands}) when is_atom(operator) and is_list(operands) do
    Enum.flat_map(operands, &do_extract_variables/1)
  end

  defp do_extract_variables({operator, operand}) when is_atom(operator) do
    do_extract_variables(operand)
  end

  defp do_extract_variables(_literal) do
    # Literals (numbers, strings, booleans) have no variables
    []
  end

  @doc """
  Add multiple variables to a context at once.

  This is useful for setting up an evaluation context with all known setting values.

  ## Examples

      context = new_context()
      |> add_variables(%{"setting_a" => 10, "setting_b" => 20})

  """
  @spec add_variables(Context.t(), map()) :: Context.t()
  def add_variables(%Context{} = context, variables_map) when is_map(variables_map) do
    Enum.reduce(variables_map, context, fn {name, value}, acc ->
      add_variable(acc, name, value)
    end)
  end

  @doc """
  Add a single variable to a context.

  This creates a Variable struct with the value and adds it to the context.

  ## Examples

      context = new_context()
      |> add_variable("setting_a", 42.5)

  """
  @spec add_variable(Context.t(), String.t(), any()) :: Context.t()
  def add_variable(%Context{} = context, name, value) when is_binary(name) do
    variable = %Elex.Variable{
      value: value,
      type: infer_type(value)
    }

    Context.add_variable(context, name, variable)
  end

  # Helper function to infer the type of a value
  defp infer_type(value) when is_integer(value), do: :decimal
  defp infer_type(value) when is_float(value), do: :decimal
  defp infer_type(%Decimal{}), do: :decimal
  defp infer_type(value) when is_binary(value), do: :string
  defp infer_type(value) when is_boolean(value), do: :boolean
  defp infer_type(_), do: :unknown
end
