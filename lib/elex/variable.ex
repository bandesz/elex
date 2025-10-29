defmodule Elex.Variable do
  @moduledoc """
  Represents a variable with a type and a value in an expression.
  """
  defstruct [:type, :value]

  @type t :: %__MODULE__{
          type: atom(),
          value: any()
        }
end
