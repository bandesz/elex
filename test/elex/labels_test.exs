defmodule Elex.LabelsTest do
  use ExUnit.Case, async: true

  alias Elex.Labels

  describe "label/1" do
    test "returns a human-readable label for :decimal" do
      assert Labels.label(:decimal) == "number"
    end

    test "returns a human-readable label for :string" do
      assert Labels.label(:string) == "text"
    end

    test "returns a human-readable label for :boolean" do
      assert Labels.label(:boolean) == "yes/no"
    end

    test "returns a human-readable label for :unknown" do
      assert Labels.label(:unknown) == "value"
    end

    test "returns a human-readable label for nil" do
      assert Labels.label(nil) == "empty"
    end

    test "labels an empty dimension as number" do
      assert Labels.label(%Elex.Dimension{monomial: %{}}) == "number"
    end
  end

  describe "got/1" do
    test "formats nil as got empty" do
      assert Labels.got(nil) == "got empty"
    end

    test "formats an empty dimension as number" do
      assert Labels.got(%Elex.Dimension{monomial: %{}}) == "got number"
    end

    test "formats a dim tuple like a dimension struct" do
      assert Labels.got({:dim, %{length: 1}}) == "got length quantity"
    end
  end
end
