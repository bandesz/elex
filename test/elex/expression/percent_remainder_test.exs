defmodule Elex.PercentRemainderTest do
  use ExUnit.Case, async: true

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent modulo errors" do
    test "rejects mod when an argument is a percent", %{ctx: ctx} do
      assert_type_error(
        "mod(10%, 3)",
        "mod function expects number arguments, got percent",
        ctx
      )
    end
  end

  defp assert_type_error(expression, message, ctx) do
    assert Elex.validate(expression, ctx) == {:error, message}
    assert Elex.evaluate(expression, ctx) == {:error, message}
  end
end
