defmodule Elex.Function do
  @type value :: String.t() | boolean() | Decimal.t()
  @type error_reason :: term()

  @callback signature() :: %{
              name: atom(),
              arity: non_neg_integer()
            }

  @callback validate(args_ast :: [term()], context :: Elex.Context.t()) ::
              {:ok, return_type :: atom()} | {:error, reason :: term()}

  @callback call(args :: [value()]) :: {:ok, value()} | {:error, error_reason()}

  @callback documentation() :: %{
              signature: String.t(),
              description: String.t()
            }
end
