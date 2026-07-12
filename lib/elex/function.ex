defmodule Elex.Function do
  @moduledoc """
  Behaviour for implementing custom Elex functions.

  Functions are registered on a [`Elex.Context`](Elex.Context) via
  `Elex.Context.add_function/2` and invoked during
  evaluation by [`Elex.Evaluator`](Elex.Evaluator).

  ## Implementing a function

      defmodule MyApp.Functions.Double do
        @behaviour Elex.Function

        @impl Elex.Function
        def signature, do: %{name: :double, arity: 1}

        @impl Elex.Function
        def validate([arg_ast], context) do
          case Elex.Validator.validate(arg_ast, context) do
            {:ok, :decimal} -> {:ok, :decimal}
            {:ok, type} -> {:error, "double expects a number, got " <> inspect(type)}
            {:error, reason} -> {:error, reason}
          end
        end

        @impl Elex.Function
        def call([arg]), do: {:ok, Decimal.mult(arg, Decimal.new(2))}

        @impl Elex.Function
        def documentation do
          %{signature: "double(x)", description: "returns x multiplied by 2"}
        end
      end
  """

  @type value :: String.t() | boolean() | Decimal.t()
  @type error_reason :: term()

  @doc """
  Returns the function name and arity.

  The name is used in expression syntax (e.g. `my_func(1, 2)`).
  """
  @callback signature() ::
              %{
                name: atom() | String.t(),
                arity: non_neg_integer()
              }
              | %{
                  name: atom() | String.t(),
                  variadic: true,
                  min_arity: non_neg_integer()
                }

  @doc """
  Validates function arguments at parse time and returns the result type.

  Receives unevaluated AST nodes for each argument.
  """
  @callback validate(args_ast :: [term()], context :: Elex.Context.t()) ::
              {:ok, return_type :: atom()} | {:error, reason :: term()}

  @doc """
  Evaluates the function with already-evaluated argument values.

  Must return `{:ok, value}` on success or `{:error, reason}` on failure.
  """
  @callback call(args :: [value()]) :: {:ok, value()} | {:error, error_reason()}

  @doc """
  Returns human-readable documentation for the function.

  Used for introspection and documentation generation.
  """
  @callback documentation() :: %{
              signature: String.t(),
              description: String.t()
            }
end
