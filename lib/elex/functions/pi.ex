defmodule Elex.Functions.Pi do
  @behaviour Elex.Function

  alias Elex.Function

  @pi "3.141592653589793"

  @impl Function
  def signature do
    %{
      name: :pi,
      arity: 0
    }
  end

  @impl Function
  def validate(_, _context) do
    {:ok, :decimal}
  end

  @impl Function
  def call(_) do
    {:ok, Decimal.new(@pi)}
  end

  @impl Function
  def documentation do
    %{
      signature: "pi()",
      description: "returns the mathematical constant π (3.14159...)"
    }
  end
end
