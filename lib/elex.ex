defmodule Elex do
  @moduledoc """
  Elex is an expression language library for parsing, validating, and evaluating expressions.

  It supports:

  - Arithmetic operations (`+`, `-`, `*`, `/`, `%`) and unary minus
  - Comparison operators (`<`, `>`, `<=`, `>=`, `==`, `!=`) for decimals,
    booleans, strings, and `null`
  - Boolean operations (`and`, `or`, `not`) with short-circuit evaluation
  - Literals: decimals, booleans (`true`/`false`, `yes`/`no`), strings, `null`
  - Variables and built-in functions (`abs`, `between`, `ceil`, `clamp`,
    `coalesce`, `concat`, `contains`, `ends_with`, `floor`, `if`, `length`,
    `lower`, `match`, `max`, `min`, `mod`, `pi`, `pow`, `rem`, `round`,
    `sqrt`, `starts_with`, `trim`, `upper`)
  - Variadic `min`, `max`, and `coalesce` (two or more arguments) and
    `concat` (zero or more arguments)
  - Type checking and validation

  ## Quick start

      context =
        Elex.new_context()
        |> Elex.add_variable("x", 10)
        |> Elex.add_variable("y", 5)

      Elex.evaluate("x + y * 2", context)
      #=> {:ok, #Decimal<20>}

      Elex.validate("x > 0", context)
      #=> {:ok, :boolean}

      Elex.extract_variables("x + y")
      #=> {:ok, ["x", "y"]}

  ## Guides

  - [Getting Started](getting-started.html)
  - [Expression Language](expression-language.html)
  - [Functions](functions.html)
  - [Ash Integration](ash-integration.html)
  - [Advanced Topics](advanced.html)

  See [`Elex.Parser`](Elex.Parser) for parsing, [`Elex.Evaluator`](Elex.Evaluator) for
  direct AST evaluation, and [`Elex.Context`](Elex.Context) for custom variables and
  functions.
  """

  alias Elex.Context

  @standard_functions [
    Elex.Functions.Abs,
    Elex.Functions.Between,
    Elex.Functions.Ceil,
    Elex.Functions.Clamp,
    Elex.Functions.Coalesce,
    Elex.Functions.Concat,
    Elex.Functions.Contains,
    Elex.Functions.EndsWith,
    Elex.Functions.Floor,
    Elex.Functions.If,
    Elex.Functions.Length,
    Elex.Functions.Lower,
    Elex.Functions.Match,
    Elex.Functions.Max,
    Elex.Functions.Min,
    Elex.Functions.Mod,
    Elex.Functions.Pi,
    Elex.Functions.Pow,
    Elex.Functions.Rem,
    Elex.Functions.Round,
    Elex.Functions.Sqrt,
    Elex.Functions.StartsWith,
    Elex.Functions.Trim,
    Elex.Functions.Upper
  ]

  @doc """
  Creates a new evaluation context with standard functions and optional variables.

  ## Parameters

  - `variables` - Map of variable names to [`Elex.Variable`](Elex.Variable) structs.
    Defaults to an empty map.

  ## Returns

  A [`Elex.Context`](Elex.Context) struct ready for parsing and evaluation.

  ## Examples

      Elex.new_context()

      Elex.new_context(%{
        "x" => %Elex.Variable{value: Decimal.new(1), type: :decimal}
      })

  """
  @spec new_context(%{optional(String.t()) => Elex.Variable.t()}) :: Context.t()
  def new_context(variables \\ %{}) when is_map(variables) do
    context = %Context{variables: variables}

    Enum.reduce(@standard_functions, context, fn module, acc ->
      Context.add_function(acc, module)
    end)
  end

  @doc """
  Returns the list of built-in function modules registered by `new_context/0`.

  Use this to distinguish standard functions from custom ones without relying on
  module-name heuristics.

  ## Examples

      Elex.list_standard_function_modules()
      #=> [Elex.Functions.Abs, Elex.Functions.Between, ...]

  """
  @spec list_standard_function_modules() :: [module()]
  def list_standard_function_modules, do: @standard_functions

  @doc """
  Parses, validates, and evaluates an expression string.

  Returns `{:ok, result}` on success or `{:error, reason}` on parse, validation, or
  evaluation failure (including arithmetic errors such as division by zero).

  ## Parameters

  - `expression_string` - The expression to evaluate
  - `context` - A [`Elex.Context`](Elex.Context) with variables and functions

  ## Returns

  - `{:ok, result}` - The evaluated result (`Decimal.t()`, `boolean()`, `String.t()`, or `nil`)
  - `{:error, reason}` - A human-readable error message

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      Elex.evaluate("x + 5", context)
      #=> {:ok, #Decimal<15>}

  """
  @spec evaluate(String.t(), Context.t()) ::
          {:ok, Decimal.t() | boolean() | String.t() | nil} | {:error, String.t()}
  def evaluate(expression_string, context) do
    with {:ok, ast, _type} <- Elex.Parser.parse(expression_string, context),
         result <- Elex.Evaluator.evaluate(ast, context) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    e in [RuntimeError, Decimal.Error] ->
      {:error, "Evaluation error: #{Exception.message(e)}"}
  end

  @doc """
  Parses and validates an expression string without evaluating it.

  ## Parameters

  - `expression_string` - The expression to validate
  - `context` - A [`Elex.Context`](Elex.Context) with variables and functions

  ## Returns

  - `{:ok, type}` - The expression's result type (`:decimal`, `:boolean`, or `:string`)
  - `{:error, reason}` - A human-readable error message

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      Elex.validate("x > 0", context)
      #=> {:ok, :boolean}

  """
  @spec validate(String.t(), Context.t()) :: {:ok, atom()} | {:error, String.t()}
  def validate(expression_string, context) do
    Elex.Parser.parse(expression_string, context)
    |> case do
      {:ok, _ast, type} -> {:ok, type}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extracts variable names referenced in an expression string.

  Parsing is performed without validation, so variables need not exist in the context.

  ## Parameters

  - `expression_string` - The expression to analyse

  ## Returns

  - `{:ok, names}` - A deduplicated list of variable name strings
  - `{:error, reason}` - A parse error message

  ## Examples

      Elex.extract_variables("x + y * 2")
      #=> {:ok, ["x", "y"]}

  """
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

  This creates a [`Elex.Variable`](Elex.Variable) struct with the value and adds it to
  the context.

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

  defp infer_type(value) when is_integer(value), do: :decimal
  defp infer_type(value) when is_float(value), do: :decimal
  defp infer_type(%Decimal{}), do: :decimal
  defp infer_type(value) when is_binary(value), do: :string
  defp infer_type(value) when is_boolean(value), do: :boolean
  defp infer_type(nil), do: nil
  defp infer_type(_), do: :unknown
end
