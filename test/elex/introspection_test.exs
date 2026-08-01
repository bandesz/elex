defmodule Elex.IntrospectionTest do
  use ExUnit.Case, async: true

  alias Elex

  describe "list_standard_function_modules/0" do
    test "returns all built-in function modules" do
      modules = Elex.list_standard_function_modules()

      assert Elex.Functions.Abs in modules
      assert Elex.Functions.Max in modules
      assert Elex.Functions.Coalesce in modules
    end

    test "matches functions registered by new_context/0" do
      context = Elex.new_context()
      registered = Map.values(context.functions) |> Enum.uniq() |> Enum.sort()
      standard = Elex.list_standard_function_modules() |> Enum.sort()

      assert registered == standard
    end
  end
end
