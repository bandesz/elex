defmodule Elex.Context do
  @moduledoc """
  Represents the context for evaluating an expression, holding available variables.
  """
  alias Elex.Variable

  defstruct variables: %{}, functions: %{}

  @type t :: %__MODULE__{
          variables: %{optional(String.t()) => Variable.t()},
          functions: %{optional({String.t(), non_neg_integer()}) => module()}
        }

  def add_function(%__MODULE__{} = ctx, funmod) do
    sig = apply(funmod, :signature, [])
    # Convert atom name to string for safe storage
    func_name = if is_atom(sig.name), do: Atom.to_string(sig.name), else: sig.name
    Map.put(ctx, :functions, Map.put(ctx.functions, {func_name, sig.arity}, funmod))
  end

  def add_variable(%__MODULE__{} = ctx, name, var) do
    Map.put(ctx, :variables, Map.put(ctx.variables, name, var))
  end
end
