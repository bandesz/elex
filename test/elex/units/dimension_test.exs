defmodule Elex.Units.DimensionTest do
  use ExUnit.Case, async: true

  alias Elex.Dimension

  describe "inspect/1" do
    test "pretty-prints a squared denominator with a caret" do
      dim = %Dimension{monomial: %{length: 1, time: -2}}

      assert inspect(dim) == "#Elex.Dimension<length | time^2>"
    end

    test "pretty-prints a quotient of base categories" do
      dim = %Dimension{monomial: %{length: 1, time: -1}}

      assert inspect(dim) == "#Elex.Dimension<length | time>"
    end

    test "pretty-prints a squared category with a caret" do
      dim = %Dimension{monomial: %{length: 2}}

      assert inspect(dim) == "#Elex.Dimension<length^2>"
    end

    test "pretty-prints a multi-factor denominator with *" do
      dim = %Dimension{monomial: %{length: 1, mass: -1, time: -2}}

      assert inspect(dim) == "#Elex.Dimension<length | mass * time^2>"
    end

    test "labels an empty monomial as number" do
      dim = %Dimension{monomial: %{}}

      assert Dimension.formula(dim) == "number"
      assert inspect(dim) == "#Elex.Dimension<number>"
      assert to_string(dim) == "number"
    end
  end
end
