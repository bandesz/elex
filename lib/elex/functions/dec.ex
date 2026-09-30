defmodule Elex.Functions.Dec do
  @moduledoc """
  Decreases a value by a percent rate.

  `dec(100, 10%)` is `90`, the same as `100 * (100% - 10%)`.

  ## Expression syntax

      dec(100, 10%)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Functions.PercentAdjust

  @impl Function
  @doc false
  def signature do
    %{
      name: :dec,
      arity: 2,
      units: :additive
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    PercentAdjust.validate("dec", args_ast, context)
  end

  @impl Function
  @doc false
  def call(args) do
    PercentAdjust.call(:dec, args)
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "dec(value, rate)",
      description: "returns value decreased by a percent rate",
      category: :math
    }
  end
end
