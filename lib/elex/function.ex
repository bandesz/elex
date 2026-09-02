defmodule Elex.Function do
  @moduledoc """
  Behaviour for implementing custom Elex functions.

  Functions are registered on a [`Elex.Context`](Elex.Context) via
  `Elex.Context.add_function/2` and invoked during
  evaluation by [`Elex.Evaluator`](Elex.Evaluator).

  ## `units:`

  `signature/0` may include `units: :point | :additive | :none | :convert | :wrap | :unwrap`.
  Omitted `units:` is `:additive`.

  * `:point` — same category. The result unit is the first **quantity**
    argument (boolean/`null` args are skipped). Additive categories convert
    later quantity args into that unit. Non-additive categories require
    `Elex.Unit.same?/2` (no silent F→C).
  * `:additive` — reject non-additive arguments. Linear same-category args
    still convert into the first quantity argument's unit. This is the
    default, so unmarked `double(1C)` errors and `double(1m)` works.
  * `:none` — reject all quantities (`sqrt`, `pow`, strings, `pi`).
  * `:convert` — first arg a quantity, second a string target; result unit
    is the target (`convert/2`).
  * `:wrap` — number plus a registered name or alias (`add_unit/2`).
  * `:unwrap` — quantity to a number (`remove_unit/1`).

  ## Implementing a function

  Preserve the unit of an additive quantity (unwrap, then rewrap). See
  [Advanced Topics](advanced.html#custom-functions) for reject,
  `:point` preserve, and same-category multi-arg patterns.

      defmodule MyApp.Functions.Double do
        @behaviour Elex.Function

        @impl Elex.Function
        def signature, do: %{name: :double, arity: 1}

        @impl Elex.Function
        def validate([arg_ast], context) do
          case Elex.Validator.same_numeric_type([arg_ast], context) do
            {:ok, type} -> {:ok, type}
            {:mismatch, type} -> {:error, "double expects a number, got " <> inspect(type)}
            {:error, reason} -> {:error, reason}
          end
        end

        @impl Elex.Function
        def call([%Elex.Quantity{value: value, unit: unit}]) do
          {:ok, doubled} = call([value])
          {:ok, %Elex.Quantity{value: doubled, unit: unit}}
        end

        def call([arg]) when is_struct(arg, Decimal) do
          {:ok, Decimal.mult(arg, Decimal.new(2))}
        end

        @impl Elex.Function
        def documentation do
          %{signature: "double(x)", description: "returns x multiplied by 2"}
        end
      end
  """

  @typedoc """
  An evaluated argument or return value. With a unit catalog, numeric
  arguments may be an [`Elex.Quantity.t()`](`Elex.Quantity`).
  """
  @type value :: String.t() | boolean() | Decimal.t() | Elex.Quantity.t() | nil
  @type error_reason :: term()

  @typedoc """
  How the function treats unitful arguments.

  * `:point` — same category; result unit is the first quantity argument
  * `:additive` — reject non-additive args (default when `units:` is omitted)
  * `:none` — reject all quantities
  * `:convert` — convert a quantity into a string target unit
  * `:wrap` — attach a registered symbol to a number
  * `:unwrap` — strip a quantity's unit
  """
  @type units :: :point | :additive | :none | :convert | :wrap | :unwrap

  @doc """
  Returns the function name, arity, and optional `units:` policy.

  The name is used in expression syntax (e.g. `my_func(1, 2)`).
  """
  @callback signature() ::
              %{
                required(:name) => atom() | String.t(),
                required(:arity) => non_neg_integer(),
                optional(:units) => units()
              }
              | %{
                  required(:name) => atom() | String.t(),
                  required(:variadic) => true,
                  required(:min_arity) => non_neg_integer(),
                  optional(:units) => units()
                }

  @doc """
  Validates function arguments at parse time and returns the result type.

  Receives unevaluated AST nodes for each argument.
  """
  @callback validate(args_ast :: [term()], context :: Elex.Context.t()) ::
              {:ok, return_type :: atom() | Elex.Dimension.t()} | {:error, reason :: term()}

  @doc """
  Evaluates the function with already-evaluated argument values.

  Must return `{:ok, value}` on success or `{:error, reason}` on failure.

  Numeric arguments may be [`Elex.Quantity.t()`](`Elex.Quantity`). For
  `:additive` functions, and for `:point` functions on additive categories,
  the evaluator converts later quantity arguments into the first **quantity**
  argument's unit before `call/1`.

  Functions that short-circuit (`if`, `coalesce`) may implement
  `evaluate_call/2` instead of relying on eager `call/1`. Functions that
  need the catalog (`convert`, `add_unit`) may implement `call/2`.
  """
  @callback call(args :: [value()]) :: {:ok, value()} | {:error, error_reason()}

  @doc """
  Optionally evaluate a call from argument ASTs (for short-circuit).

  When this callback is exported, the evaluator does not eagerly evaluate
  every argument. Implement it on functions like `if` and `coalesce`.
  """
  @callback evaluate_call(args_ast :: [term()], context :: Elex.Context.t()) ::
              {:ok, value()} | {:error, error_reason()}

  @doc """
  Optionally evaluate with the context (for catalog-aware functions).

  When `call/2` is exported it is used instead of `call/1`.
  """
  @callback call(args :: [value()], context :: Elex.Context.t()) ::
              {:ok, value()} | {:error, error_reason()}

  @optional_callbacks evaluate_call: 2, call: 2

  @doc """
  Returns human-readable documentation for the function.

  Used for introspection and documentation generation.

  An optional `:category` atom (e.g. `:math`, `:string`, `:utility`) can be
  included so host applications can group functions in documentation UIs.
  """
  @type documentation :: %{
          required(:signature) => String.t(),
          required(:description) => String.t(),
          optional(:category) => atom()
        }

  @callback documentation() :: documentation()

  @doc """
  Returns the `units:` policy from a signature map or function module.

  When `units:` is omitted, the default is `:additive`.
  """
  @spec units(module() | map()) :: units()
  def units(module) when is_atom(module), do: units(module.signature())
  def units(%{} = signature), do: Map.get(signature, :units, :additive)
end
