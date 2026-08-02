defmodule Elex.Functions.MatchTest do
  use ExUnit.Case, async: true

  alias Elex.{Parser, Evaluator, Variable}
  alias Elex

  defp parse(expression, variables \\ %{}) do
    ctx = Elex.new_context(variables)
    Parser.parse(expression, ctx)
  end

  defp parse_and_evaluate(expression, variables \\ %{}) do
    ctx = Elex.new_context(variables)

    case Parser.parse(expression, ctx) do
      {:ok, ast, _type} ->
        Evaluator.evaluate(ast, ctx)

      {:error, reason} ->
        flunk("Parsing and evaluation failed unexpectedly: #{reason}")
    end
  end

  describe "match/2 function" do
    test "returns true when text matches the pattern" do
      assert parse_and_evaluate(~s|match("hello123", "hello[0-9]+")|) == true
      assert parse_and_evaluate(~s|match("abc123", "abc\\\\d+")|) == true
    end

    test "returns false when text does not match the pattern" do
      assert parse_and_evaluate(~s|match("hello", "[0-9]+")|) == false
    end

    test "supports inline regex modifiers" do
      assert parse_and_evaluate(~s[match("HELLO", "(?i)hello")]) == true
    end

    test "evaluates with variables" do
      vars = %{
        "text" => %Variable{value: "abc123", type: :string},
        "pattern" => %Variable{value: "abc\\d+", type: :string}
      }

      assert parse_and_evaluate("match(text, pattern)", vars) == true
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s|match(concat("hel", "lo123"), "hello[0-9]+")|) == true
    end

    test "non-string argument" do
      assert {:error, "match function expects string arguments, got decimal"} =
               parse(~s[match(1, "ell")])
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} =
               parse(~s[match(missing, "ell")])
    end

    test "returns evaluation error for invalid regex pattern" do
      ctx = Elex.new_context()

      assert {:error, "Evaluation error: " <> reason} =
               Elex.evaluate(~s|match("hello", "[")|, ctx)

      assert reason =~ "invalid regex pattern"
    end

    test "wrong number of arguments" do
      assert {:error, "match function expects 2 arguments"} = parse(~s[match("hello")])
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Match.documentation()
      assert is_map(doc)
      assert doc.signature == "match(text, pattern)"
      assert is_binary(doc.description)
    end
  end
end
