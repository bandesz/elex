defmodule Elex.Functions.Inc do
  @moduledoc """
  Increases a value by a percent rate.

  `inc(100, 10%)` is `110`, the same as `100 * (100% + 10%)`.

  ## Expression syntax

      inc(100, 10%)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Functions.PercentAdjust

  @impl Function
  @doc false
  def signature do
    %{
      name: :inc,
      arity: 2,
      units: :additive
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    PercentAdjust.validate("inc", args_ast, context)
  end

  @impl Function
  @doc false
  def call(args) do
    PercentAdjust.call(:inc, args)
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "inc(value, rate)",
      description: "returns value increased by a percent rate",
      category: :math
    }
  end
end
