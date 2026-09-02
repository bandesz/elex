defmodule Elex.Units.Temperature do
  @moduledoc """
  Test catalog with Celsius as the conversion default and Fahrenheit offset from C.
  """

  alias Elex.Units.Catalog

  @spec catalog() :: Catalog.t()
  def catalog do
    {:ok, catalog} =
      Catalog.add_category(Catalog.new(), :temperature, default: "C", additive: false)

    {:ok, catalog} = Catalog.add_unit(catalog, :temperature, "C", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :temperature, "F", "(value - 32) * 5 / 9")
    catalog
  end
end
