defmodule Elex.PercentTest do
  use ExUnit.Case, async: true

  alias Elex.Percent

  describe "inspect/1" do
    test "pretty-prints a positive percent" do
      percent = %Percent{value: Decimal.new("50")}

      assert inspect(percent) == "#Elex.Percent<50%>"
    end

    test "pretty-prints a negative percent" do
      percent = %Percent{value: Decimal.new("-10")}

      assert inspect(percent) == "#Elex.Percent<-10%>"
    end

    test "drops trailing zeros from the points" do
      percent = %Percent{value: Decimal.new("50.0000")}

      assert inspect(percent) == "#Elex.Percent<50%>"
    end
  end
end
