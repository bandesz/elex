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
  - `:units` - Optional [`Elex.Units.Catalog`](Elex.Units.Catalog); `nil` (default)
    keeps unit-unaware parse, validate, and evaluate behaviour

  ## Examples

      context =
        %Elex.Context{}
        |> Elex.Context.add_function(MyApp.Functions.Double)
        |> Elex.Context.add_variable("x", %Elex.Variable{value: Decimal.new(10), type: :decimal})

  """
  alias Elex.Units.Catalog
  alias Elex.Variable

  defstruct variables: %{}, functions: %{}, units: nil

  @type t :: %__MODULE__{
          variables: %{optional(String.t()) => Variable.t()},
          functions: %{optional({String.t(), non_neg_integer() | :variadic}) => module()},
          units: nil | Catalog.t()
        }

  @type function_info :: %{
          required(:module) => module(),
          required(:name) => String.t(),
          required(:arity) => non_neg_integer() | :variadic,
          required(:signature) => String.t(),
          required(:description) => String.t(),
          optional(:min_arity) => non_neg_integer(),
          optional(:category) => atom()
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

  @doc """
  Attaches a units catalog to the context.

  ## Parameters

  - `ctx` - The context to update
  - `catalog` - An [`Elex.Units.Catalog`](Elex.Units.Catalog) built by the caller

  ## Returns

  `{:ok, context}` with `units` set to the given catalog, or
  `{:error, String.t()}` when a category `default:` hub is not among
  that category's units, or a derived category has only aliases
  (`m2`, `ha`) and no unit matching the base-hub product (`m * m`).

  ## Examples

      catalog = Elex.Units.Catalog.new()
      {:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)

  """
  @spec put_units(t(), Catalog.t()) :: {:ok, t()} | {:error, String.t()}
  def put_units(%__MODULE__{} = ctx, %Catalog{} = catalog) do
    case Catalog.validate(catalog) do
      :ok -> {:ok, %{ctx | units: catalog}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `put_units/2`, but returns the context or raises `ArgumentError`.
  """
  @spec put_units!(t(), Catalog.t()) :: t()
  def put_units!(%__MODULE__{} = ctx, %Catalog{} = catalog) do
    case put_units(ctx, catalog) do
      {:ok, ctx} -> ctx
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Returns metadata for every function registered on the context.

  Each entry is a map with `:module`, `:name`, `:arity`, `:signature`, and
  `:description`. Variadic functions use `:arity` of `:variadic` and include
  `:min_arity`. When a function's `documentation/0` callback includes
  `:category`, that key is included as well.

  The list is sorted by function name.

  ## Examples

      context = Elex.new_context()
      Elex.Context.list_functions(context)
      #=> [
      #     %{module: Elex.Functions.Abs, name: "abs", arity: 1,
      #       signature: "abs(x)", description: "...", category: :math},
      #     ...
      #   ]

  """
  @spec list_functions(t()) :: [function_info()]
  def list_functions(%__MODULE__{functions: functions}) do
    functions
    |> Enum.map(&function_info/1)
    |> Enum.sort_by(& &1.name)
  end

  defp function_info({_key, module}) do
    sig = module.signature()
    doc = module.documentation()
    name = if is_atom(sig.name), do: Atom.to_string(sig.name), else: sig.name

    base = %{
      module: module,
      name: name,
      signature: doc.signature,
      description: doc.description
    }

    info =
      if Map.get(sig, :variadic) do
        Map.merge(base, %{arity: :variadic, min_arity: sig.min_arity})
      else
        Map.put(base, :arity, sig.arity)
      end

    maybe_put_category(info, doc)
  end

  defp maybe_put_category(info, %{category: category}) when is_atom(category) do
    Map.put(info, :category, category)
  end

  defp maybe_put_category(info, _doc), do: info
end
