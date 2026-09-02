defmodule Elex.ContextTest do
  use ExUnit.Case, async: true

  alias Elex.{Context, Variable}
  alias Elex.Units.Catalog

  describe "struct initialization" do
    test "creates empty context with default values" do
      ctx = %Context{}
      assert ctx.variables == %{}
      assert ctx.functions == %{}
      assert ctx.units == nil
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

  describe "put_units/2" do
    test "puts a catalog on the context" do
      catalog = Catalog.new()
      assert {:ok, ctx} = Context.put_units(%Context{}, catalog)

      assert ctx.units == catalog
    end

    test "preserves variables and functions when putting a catalog" do
      vars = %{"x" => %Variable{value: 10, type: :decimal}}
      ctx = Context.add_function(%Context{variables: vars}, Elex.Functions.Max)
      catalog = Catalog.new()

      assert {:ok, ctx} = Context.put_units(ctx, catalog)

      assert ctx.units == catalog
      assert ctx.variables == vars
      assert Map.has_key?(ctx.functions, {"max", :variadic})
    end
  end

  describe "put_units!/2" do
    test "returns the context when the catalog is valid" do
      catalog = Catalog.new()
      ctx = Context.put_units!(%Context{}, catalog)

      assert ctx.units == catalog
    end

    test "raises ArgumentError when a default hub is not among the category units" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")

      assert_raise ArgumentError, "default 'm' is not among the units of :length", fn ->
        Context.put_units!(%Context{}, catalog)
      end
    end
  end

  describe "new_context/0" do
    test "has units nil by default" do
      ctx = Elex.new_context()
      assert ctx.units == nil
    end
  end

  describe "add_function/2" do
    test "adds function module with atom name" do
      ctx = %Context{}
      ctx = Context.add_function(ctx, Elex.Functions.Max)

      assert Map.has_key?(ctx.functions, {"max", :variadic})
      assert ctx.functions[{"max", :variadic}] == Elex.Functions.Max
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

      assert Map.has_key?(ctx.functions, {"max", :variadic})
      assert Map.has_key?(ctx.functions, {"min", :variadic})
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

      assert Map.has_key?(ctx.functions, {"max", :variadic})
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

  describe "list_functions/1" do
    test "returns empty list for empty context" do
      assert Context.list_functions(%Context{}) == []
    end

    test "returns sorted metadata for all registered functions" do
      ctx = Elex.new_context()
      functions = Context.list_functions(ctx)

      assert length(functions) == length(Elex.list_standard_function_modules())

      names = Enum.map(functions, & &1.name)
      assert names == Enum.sort(names)

      abs_info = Enum.find(functions, &(&1.name == "abs"))
      assert abs_info.module == Elex.Functions.Abs
      assert abs_info.arity == 1
      assert abs_info.signature == "abs(x)"
      assert abs_info.description == "returns the absolute value of x"
      assert abs_info.category == :math
    end

    test "includes variadic arity and min_arity" do
      ctx = Elex.new_context()
      functions = Context.list_functions(ctx)

      max_info = Enum.find(functions, &(&1.name == "max"))
      assert max_info.arity == :variadic
      assert max_info.min_arity == 2
      assert max_info.signature == "max(a, b, ...)"
      assert max_info.category == :math
    end

    test "includes custom functions without category when not provided" do
      defmodule TestIntrospectionFunction do
        @behaviour Elex.Function

        def signature, do: %{name: "custom_fn", arity: 1}
        def validate(_args, _ctx), do: {:ok, :decimal}
        def call(_args), do: {:ok, Decimal.new("1")}
        def documentation, do: %{signature: "custom_fn(x)", description: "A custom function"}
      end

      ctx = %Context{} |> Context.add_function(TestIntrospectionFunction)
      [info] = Context.list_functions(ctx)

      assert info.module == TestIntrospectionFunction
      assert info.name == "custom_fn"
      assert info.arity == 1
      assert info.signature == "custom_fn(x)"
      assert info.description == "A custom function"
      refute Map.has_key?(info, :category)
    end

    test "all standard functions include category" do
      ctx = Elex.new_context()
      functions = Context.list_functions(ctx)

      assert Enum.all?(functions, &Map.has_key?(&1, :category))
    end

    test "includes custom variadic function introspection" do
      defmodule TestVariadicIntrospectionFunction do
        @behaviour Elex.Function

        def signature, do: %{name: "custom_sum", variadic: true, min_arity: 2}
        def validate(_args, _ctx), do: {:ok, :decimal}
        def call(args), do: {:ok, Enum.reduce(args, Decimal.new(0), &Decimal.add/2)}

        def documentation do
          %{signature: "custom_sum(a, b, ...)", description: "Sums arguments", category: :math}
        end
      end

      ctx = %Context{} |> Context.add_function(TestVariadicIntrospectionFunction)
      [info] = Context.list_functions(ctx)

      assert info.module == TestVariadicIntrospectionFunction
      assert info.name == "custom_sum"
      assert info.arity == :variadic
      assert info.min_arity == 2
      assert info.signature == "custom_sum(a, b, ...)"
      assert info.description == "Sums arguments"
      assert info.category == :math
    end

    test "includes category when provided in documentation/0" do
      defmodule TestCategorizedFunction do
        @behaviour Elex.Function

        def signature, do: %{name: "categorized", arity: 0}
        def validate(_args, _ctx), do: {:ok, :string}
        def call(_args), do: {:ok, "ok"}

        def documentation,
          do: %{signature: "categorized()", description: "Test", category: :utility}
      end

      ctx = %Context{} |> Context.add_function(TestCategorizedFunction)
      [info] = Context.list_functions(ctx)

      assert info.category == :utility
    end
  end
end
