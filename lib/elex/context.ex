defmodule Elex.Context do
  @moduledoc """
  Holds variables and functions available when parsing and evaluating expressions.

  A context is required by [`Elex.Parser`](Elex.Parser) and [`Elex.Evaluator`](Elex.Evaluator).
  Use `Elex.new_context/0` to create one with standard built-in
  functions, then add variables and custom functions as needed.

  ## Fields

  - `:variables` - Map of variable name strings to [`Elex.Variable`](Elex.Variable) structs
  - `:functions` - Map of `{name, arity}` or `{name, :variadic}` tuples to modules
    implementing [`Elex.Function`](Elex.Function)

  ## Examples

      context =
        %Elex.Context{}
        |> Elex.Context.add_function(MyApp.Functions.Double)
        |> Elex.Context.add_variable("x", %Elex.Variable{value: Decimal.new(10), type: :decimal})

  """
  alias Elex.Variable

  defstruct variables: %{}, functions: %{}

  @type t :: %__MODULE__{
          variables: %{optional(String.t()) => Variable.t()},
          functions: %{optional({String.t(), non_neg_integer() | :variadic}) => module()}
        }

  @doc """
  Registers a function module on the context.

  ## Parameters

  - `ctx` - The context to update
  - `funmod` - A module implementing [`Elex.Function`](Elex.Function)

  ## Returns

  An updated context with the function registered under its `signature/0` name and arity.

  ## Examples

      context = Elex.new_context()
      |> Elex.Context.add_function(MyApp.Functions.Double)

  """
  @spec add_function(t(), module()) :: t()
  def add_function(%__MODULE__{} = ctx, funmod) do
    sig = apply(funmod, :signature, [])
    func_name = if is_atom(sig.name), do: Atom.to_string(sig.name), else: sig.name

    key =
      if Map.get(sig, :variadic) do
        {func_name, :variadic}
      else
        {func_name, sig.arity}
      end

    Map.put(ctx, :functions, Map.put(ctx.functions, key, funmod))
  end

  @doc """
  Adds a variable to the context.

  ## Parameters

  - `ctx` - The context to update
  - `name` - Variable name as used in expressions (e.g. `"x"`)
  - `var` - A [`Elex.Variable`](Elex.Variable) struct with type and value

  ## Returns

  An updated context with the variable registered.

  ## Examples

      variable = %Elex.Variable{value: Decimal.new(42), type: :decimal}
      Elex.Context.add_variable(Elex.new_context(), "answer", variable)

  """
  @spec add_variable(t(), String.t(), Variable.t()) :: t()
  def add_variable(%__MODULE__{} = ctx, name, var) do
    Map.put(ctx, :variables, Map.put(ctx.variables, name, var))
  end
end
