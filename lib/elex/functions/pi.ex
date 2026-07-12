defmodule Elex.Functions.Pi do
  @moduledoc """
  Returns the mathematical constant π (3.14159...).

  ## Expression syntax

      pi()
  """
  @behaviour Elex.Function

  alias Elex.Function

  @pi "3.141592653589793"

  @impl Function
  @doc false
  def signature do
    %{
      name: :pi,
      arity: 0
    }
  end

  @impl Function
  @doc false
  def validate(_, _context) do
    {:ok, :decimal}
  end

  @impl Function
  @doc false
  def call(_) do
    {:ok, Decimal.new(@pi)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "pi()",
      description: "returns the mathematical constant π (3.14159...)"
    }
  end
end
