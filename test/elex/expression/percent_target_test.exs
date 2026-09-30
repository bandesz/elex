defmodule Elex.PercentTargetTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog

  setup do
    %{ctx: length_context()}
  end

  test "validate category: :length on a percent expects length", %{ctx: ctx} do
    assert {:error, message} = Elex.validate("50%", ctx, category: :length)
    assert message == "length was expected, got percent"
  end

  test "evaluate unit: on a percent cannot convert to a unit", %{ctx: ctx} do
    assert {:error, message} = Elex.evaluate("50%", ctx, unit: "cm")
    assert message == "cannot convert percent to a unit"
  end

  test "convert rejects a percent with no catalog" do
    ctx = Elex.new_context()
    message = "convert function expects a unitful value, got percent"

    assert Elex.validate(~S|convert(50%, "cm")|, ctx) == {:error, message}
    assert Elex.evaluate(~S|convert(50%, "cm")|, ctx) == {:error, message}
  end

  test "convert rejects a percent with a length catalog", %{ctx: ctx} do
    message = "convert function expects a unitful value, got percent"

    assert Elex.validate(~S|convert(50%, "cm")|, ctx) == {:error, message}
    assert Elex.evaluate(~S|convert(50%, "cm")|, ctx) == {:error, message}
  end

  test "remove_unit rejects a percent" do
    ctx = Elex.new_context()
    message = "remove_unit function expects a unitful value, got percent"

    assert Elex.validate("remove_unit(50%)", ctx) == {:error, message}
    assert Elex.evaluate("remove_unit(50%)", ctx) == {:error, message}
  end

  defp length_context do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end
end
