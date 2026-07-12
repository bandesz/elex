defmodule Elex.Variable do
  @moduledoc """
  A named value with a type used during expression validation and evaluation.

  Variables are stored on a [`Elex.Context`](Elex.Context) and referenced in expressions
  by name. The `:type` field drives type checking in [`Elex.Validator`](Elex.Validator);
  the `:value` field is returned by [`Elex.Evaluator`](Elex.Evaluator).

  ## Fields

  - `:type` - One of `:decimal`, `:boolean`, `:string`, `nil`, or `:unknown`
  - `:value` - The runtime value (`Decimal.t()`, `boolean()`, `String.t()`, etc.)

  ## Examples

      %Elex.Variable{value: Decimal.new("3.14"), type: :decimal}
      %Elex.Variable{value: true, type: :boolean}
      %Elex.Variable{value: "hello", type: :string}

  Use `Elex.add_variable/3` to infer the type from a value.
  """
  defstruct [:type, :value]

  @typedoc """
  A variable with a known type and runtime value.
  """
  @type t :: %__MODULE__{
          type: atom(),
          value: any()
        }
end
