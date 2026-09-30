defmodule Elex.PercentRemainderTest do
  use ExUnit.Case, async: true

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent remainder errors" do
    test "rejects rem when either argument is a percent", %{ctx: ctx} do
      message = "rem function expects number arguments, got percent"

      assert_type_error("rem(10%, 3)", message, ctx)
      assert_type_error("rem(10, 3%)", message, ctx)
    end

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
