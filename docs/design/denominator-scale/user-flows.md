# User flows

Canonical behaviour for a registered denominator coefficient such as litres per 100 km. Actor is always a **library caller**. Catalogs are test/caller fixtures.

## Catalog fixture

Used by Flows 1–3 unless a step says otherwise.

- `:volume` default `L`. `L` converts with `"value"`. `mL` converts with `"value / 1000"`.
- `:length` default `km`. `km` converts with `"value"`.
- `:consumption` formula `volume | length`, default `L | km`.

## Flow 1: Register the scaled unit

**Actor:** library caller
**Precondition:** `:volume` and `:length` exist, as in the fixture. `:consumption` exists with formula `volume | length` and default `L | km`.

**Steps:**

1. `Catalog.add_unit(catalog, :consumption, "L | km", "value")` → `{:ok, catalog}`
2. `Catalog.add_unit(catalog, :consumption, "L | 100 km", "value / 100")` → `{:ok, catalog}`
3. `Catalog.add_unit(catalog, :consumption, "mL | 100 km", "value / 100000")` → `{:ok, catalog}`
4. `Context.put_units(ctx, catalog)` → `{:ok, ctx}`

**Error paths:**

- `"L | 100 km"` with `"value / 50"`, or with the conversion omitted (`"value"`) → `unit 'L | 100 km' conversion does not match the scale of its component units`
- `"mL | 100 km"` with `"value / 100"` → `unit 'mL | 100 km' conversion does not match the scale of its component units`
- A second canonical name with the same monomial and the same `per`, such as `"L|100km"` after `"L | 100 km"` → `unit 'L|100km' has the same scale as 'L | 100 km'`
- `"L | 50 km"` with `"value / 50"` after `"L | 100 km"` → `{:ok, catalog}` (same monomial, different `per`)
- `"L | 100 km"` registered on `:length` → `formula 'L | 100 km' does not match the category dimension`
- `Catalog.add_category(..., default: "L | 100 km")` → `default unit 'L | 100 km' cannot include a denominator coefficient`
- `:consumption` default is the opaque registered unit `"cons"` (`"value"`), `"L | 100 km"` is registered with `"value / 100"`, and `"L | km"` is not registered. `:volume` and `:length` are the fixture hubs. `Context.put_units` returns `derived category :consumption needs a registered unit matching the base hubs (e.g. "L | km")`

## Flow 2: Write, inspect, and convert

**Actor:** library caller
**Precondition:** Flow 1 succeeded and the catalog is attached

**Steps:**

1. `evaluate("8 {L | 100 km}", ctx)` → `{:ok, quantity}` whose inspect is `#Elex.Quantity<8 L | 100 km>`. Value is decimal `8`. Unit monomial is `%{"L" => 1, "km" => -1}` and `per` is `100`.
2. `evaluate("8 {L|100km}", ctx)` → the same value, monomial, `per`, and inspect
3. `evaluate("8 {L | 100 km}", ctx, unit: "L | km")` → inspect `#Elex.Quantity<0.08 L | km>`, `per` is `1`
4. `evaluate("0.08 {L | km}", ctx, unit: "L | 100 km")` → inspect `#Elex.Quantity<8 L | 100 km>`
5. `evaluate("convert(8 {L | 100 km}, \"L | km\")", ctx)` → the same `0.08 L | km` result as step 3
6. `evaluate("8 {mL | 100 km}", ctx, unit: "L | 100 km")` → inspect `#Elex.Quantity<0.008 L | 100 km>`
7. `validate("8 {L | 100 km}", ctx)` → `{:ok, dimension}` whose inspect is `#Elex.Dimension<volume | length>`
8. `validate("8 {L | 100 km}", ctx, category: :consumption)` → the same dimension
9. `evaluate("add_unit(8, \"L | 100 km\")", ctx)` → inspect `#Elex.Quantity<8 L | 100 km>`
10. `evaluate("8 L | 100 km", ctx)` → the same quantity and inspect as step 1
11. `evaluate("8L|100km", ctx)` → the same quantity and inspect as step 1
12. `evaluate("8 L | 100 km * 2", ctx)` → inspect `#Elex.Quantity<16 L | 100 km>` (the suffix ends at `km`; `* 2` multiplies the quantity)

**Error paths:**

- `evaluate("8 {L | 50 km}", ctx)` → `{:error, "unknown unit 'L | 50 km'"}`
- `validate("8 {L | 50 km}", ctx)` → `{:error, "unknown unit 'L | 50 km'"}`
- `evaluate("8 L | 50 km", ctx)` → `{:error, "unknown unit 'L | 50 km'"}`
- `evaluate("8 {L | 100 km}", ctx, unit: "L | 50 km")` → `{:error, "unknown unit 'L | 50 km'"}`
- `evaluate("8 L | 100 * km", ctx)` and `evaluate("8 {L | 100 * km}", ctx)` → `{:error, "invalid formula 'L | 100 * km'"}`
- `evaluate("8 L | 100 km * km", ctx)` → `unbraced pipe suffixes cannot continue with '* km'; write a power on the denominator or a braced formula`
- `evaluate("add_unit(8, \"L | 50 km\")", ctx)` → `add_unit expects a registered unit symbol, got 'L | 50 km'`

## Flow 3: Arithmetic

**Actor:** library caller
**Precondition:** Flow 1 catalog is attached

**Steps:**

1. `8 {L | 100 km} + 2 {L | 100 km}` → `#Elex.Quantity<10 L | 100 km>`
2. `8 {L | 100 km} + 0.02 {L | km}` → `#Elex.Quantity<10 L | 100 km>`
3. `0.02 {L | km} + 8 {L | 100 km}` → `#Elex.Quantity<0.1 L | km>`
4. `8 {L | 100 km} * 100 km` → `#Elex.Quantity<8 L>`
5. `2 * 8 {L | 100 km}` → `#Elex.Quantity<16 L | 100 km>`
6. `8 {L | 100 km} / 2 {L | 100 km}` → decimal `4`
7. `8 {L | 100 km} == 0.08 {L | km}` → `true`
8. `min(8 {L | 100 km}, 0.1 {L | km})` → `#Elex.Quantity<8 L | 100 km>`
9. `8 {L | 100 km} * 3 {L | 100 km}` → `#Elex.Quantity<0.0024 L^2 | km^2>`
10. `1 / 8 {L | 100 km}` → `#Elex.Quantity<12.5 km | L>`
11. `0 {L | 100 km}` → `#Elex.Quantity<0 L | 100 km>`
12. `-8 {L | 100 km}` → `#Elex.Quantity<-8 L | 100 km>`
13. `8 {L | 100 km} / 0.02 {L | km}` → decimal `4`

**Error paths:**

- `8 {L | 100 km} + 1` → `cannot add consumption and number`
- `1 / 0 {L | 100 km}` → `division by zero`

## Flow 4: Formulas that are rejected before registration

**Actor:** library caller
**Precondition:** a catalog is being built, or `Formula.parse/1` is called directly

**Steps:**

1. `Formula.parse("L | 100 km")` and `Formula.parse("L|100km")` → `{:ok, %{"L" => 1, "km" => -1}, 100}`
2. `Formula.parse("1 | 100 s")` → `{:ok, %{"s" => -1}, 100}`
3. `Formula.parse("L | km")` and `Formula.parse("1 | s")` stay two-tuples: `{:ok, monomial}` with no third element
4. `Formula.parse("L | 100 km * m")` → `{:ok, %{"L" => 1, "km" => -1, "m" => -1}, 100}`

**Error paths:**

- `Formula.parse("100 km | h")` → `{:error, "invalid formula '100 km | h'"}`
- `Formula.parse("L | 100 * km")` → `{:error, "invalid formula 'L | 100 * km'"}`
- `Formula.parse("L | km * 100")` → `{:error, "invalid formula 'L | km * 100'"}`
- `Formula.parse("L | 1 km")` → `{:error, "invalid formula 'L | 1 km'"}`
- `Formula.parse("L | 0 km")` → `{:error, "invalid formula 'L | 0 km'"}`
- `Formula.parse("L | 01 km")` → `{:error, "invalid formula 'L | 01 km'"}`
- `Formula.parse("L | 100 km * 2")` → `{:error, "invalid formula 'L | 100 km * 2'"}`
