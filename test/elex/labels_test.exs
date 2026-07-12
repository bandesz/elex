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
  end
end
