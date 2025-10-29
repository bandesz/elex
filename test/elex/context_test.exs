defmodule Elex.ContextTest do
  use ExUnit.Case, async: true

  alias Elex.{Context, Variable}

  describe "struct initialization" do
    test "creates empty context with default values" do
      ctx = %Context{}
      assert ctx.variables == %{}
      assert ctx.functions == %{}
    end

    test "creates context with initial variables" do
      vars = %{
        "x" => %Variable{value: 10, type: :decimal},
        "y" => %Variable{value: 20, type: :decimal}
      }

      ctx = %Context{variables: vars}
      assert ctx.variables == vars
    end

    test "creates context with initial functions" do
      funcs = %{{"func", 1} => SomeModule}
      ctx = %Context{functions: funcs}
      assert ctx.functions == funcs
    end
  end

  describe "add_function/2" do
    test "adds function module with atom name" do
      ctx = %Context{}
      ctx = Context.add_function(ctx, Elex.Functions.Max)

      assert Map.has_key?(ctx.functions, {"max", 2})
      assert ctx.functions[{"max", 2}] == Elex.Functions.Max
    end

    test "adds function module with string name" do
      defmodule TestFunctionWithStringName do
        @behaviour Elex.Function

        def signature, do: %{name: "test_func", arity: 1}
        def validate(_args, _ctx), do: {:ok, :decimal}
        def call(_args), do: {:ok, Decimal.new("42")}
        def documentation, do: %{signature: "test_func(x)", description: "Test function"}
      end

      ctx = %Context{}
      ctx = Context.add_function(ctx, TestFunctionWithStringName)

      assert Map.has_key?(ctx.functions, {"test_func", 1})
      assert ctx.functions[{"test_func", 1}] == TestFunctionWithStringName
    end

    test "preserves existing functions when adding new one" do
      ctx = %Context{}
      ctx = Context.add_function(ctx, Elex.Functions.Max)
      ctx = Context.add_function(ctx, Elex.Functions.Min)

      assert Map.has_key?(ctx.functions, {"max", 2})
      assert Map.has_key?(ctx.functions, {"min", 2})
    end

    test "preserves variables when adding functions" do
      vars = %{"x" => %Variable{value: 10, type: :decimal}}
      ctx = %Context{variables: vars}
      ctx = Context.add_function(ctx, Elex.Functions.Max)

      assert ctx.variables == vars
    end
  end

  describe "add_variable/3" do
    test "adds variable to empty context" do
      ctx = %Context{}
      var = %Variable{value: 42, type: :decimal}
      ctx = Context.add_variable(ctx, "num", var)

      assert ctx.variables["num"] == var
    end

    test "adds variable to context with existing variables" do
      ctx = %Context{variables: %{"x" => %Variable{value: 10, type: :decimal}}}
      var = %Variable{value: 20, type: :decimal}
      ctx = Context.add_variable(ctx, "y", var)

      assert ctx.variables["x"].value == 10
      assert ctx.variables["y"] == var
    end

    test "overwrites existing variable with same name" do
      ctx = %Context{variables: %{"x" => %Variable{value: 10, type: :decimal}}}
      var = %Variable{value: 99, type: :decimal}
      ctx = Context.add_variable(ctx, "x", var)

      assert ctx.variables["x"] == var
      assert ctx.variables["x"].value == 99
    end

    test "preserves functions when adding variables" do
      ctx = Context.add_function(%Context{}, Elex.Functions.Max)
      var = %Variable{value: 42, type: :decimal}
      ctx = Context.add_variable(ctx, "num", var)

      assert Map.has_key?(ctx.functions, {"max", 2})
    end

    test "handles different variable types" do
      ctx = %Context{}

      ctx =
        ctx
        |> Context.add_variable("dec", %Variable{value: Decimal.new("3.14"), type: :decimal})
        |> Context.add_variable("str", %Variable{value: "hello", type: :string})
        |> Context.add_variable("bool", %Variable{value: true, type: :boolean})

      assert ctx.variables["dec"].type == :decimal
      assert ctx.variables["str"].type == :string
      assert ctx.variables["bool"].type == :boolean
    end
  end
end
