# User flows

Canonical behaviour for a unit marked `derivable: false`. Actor is always a **library caller**. Catalogs are test fixtures. Elex still ships no units.

## Catalog fixture

Used by Flows 1–4 unless a step says otherwise.

- `:length` default `m`. `m` converts with `"value"`. `km` converts with `"value * 1000"`.
- `:volume` formula `length * length * length`, default `m^3`. `m^3` and `cm^3` omit `derivable:` (`cm^3` converts with `"value / 1000000"`). `L` converts with `"value / 1000"` and `derivable: false`. `mL` converts with `"value / 1000000"` and `derivable: false`. `gallon` converts with `"value * 0.003785411784"` and `derivable: false`.
- `:fuel` formula `volume | length`, default `L | km`. Flow 4 sets `additive: false`. Other flows leave `additive:` at its default `true`.

`ha` is not in this fixture. Flow 6 uses the existing hectare catalog: `:area` default `ha`, `identity: "m^2"`, `m^2` at `"value / 10000"`, and `ha` omits `derivable:`.

## Flow 1: Register fuel and litres per 100 km

**Actor:** library caller
**Precondition:** `:length` and `:volume` exist as in the fixture, including `L` with `derivable: false`. `:fuel` does not exist yet.

**Steps:**

1. `Catalog.add_category(catalog, :fuel, formula: "volume | length", default: "L | km")` → `{:ok, catalog}`. `Catalog.dimension(catalog, :fuel)` → `{:ok, #Elex.Dimension<volume | length>}`.
2. `Catalog.add_unit(catalog, :fuel, "L | km", "value")` → `{:ok, catalog}`
3. `Catalog.add_unit(catalog, :fuel, "L | 100 km", "value / 100")` → `{:ok, catalog}`
4. `Context.put_units(Elex.new_context(), catalog)` → `{:ok, ctx}`, without a registered `m^3 | m`

**Error paths:**

- Step 1 with `default: "L | 100 km"` → `default unit 'L | 100 km' cannot include a denominator coefficient`. `:fuel` is not registered.
- Step 1 with `identity: "m^3 | m"` → `identity: is not allowed when :fuel formula names a derived category`. `:fuel` is not registered.
- `L` registered without `derivable: false`, then `"L | km"` on `:fuel` → `formula 'L | km' repeats category :length in the numerator and denominator`
- `"m^3 | m"` on `:fuel` → `formula 'm^3 | m' repeats category :length in the numerator and denominator`
- `"L | 100 km"` with `"value"` or with the conversion omitted → `unit 'L | 100 km' conversion does not match the scale of its component units`
- `"mL | 100 km"` with `"value / 100"` → `unit 'mL | 100 km' conversion does not match the scale of its component units`
- `"mL | 100 km"` with `"value / 100000"` → `{:ok, catalog}`
- `"L|100km"` with `"value / 100"` after step 3 → `unit 'L|100km' has the same scale as 'L | 100 km'`
- A second category `formula: "volume | length"` → `category :economy has the same dimension as :fuel`

## Flow 2: Litre stays volume per length

**Actor:** library caller
**Precondition:** Flow 1 succeeded through `put_units`. `L | km` and `L | 100 km` are registered.

**Steps:**

1. `evaluate("1 L / 1 m", ctx)` → `#Elex.Quantity<1 L | m>`
2. `validate("1 L / 1 m", ctx)` → `{:ok, #Elex.Dimension<volume | length>}`
3. `evaluate("1 L / 1 km", ctx)` → `#Elex.Quantity<1 L | km>`
4. `validate("1 L / 1 km", ctx)` → the same dimension as step 2
5. `evaluate("8 L | 100 km", ctx)` → `#Elex.Quantity<8 L | 100 km>`
6. `evaluate("8 L|100km", ctx)` → the same quantity as step 5
7. `validate("8 {L | 100 km}", ctx)` → `{:ok, #Elex.Dimension<volume | length>}`
8. `convert(1 L, "m^3")` → `#Elex.Quantity<0.001 m^3>`

**Error paths:**

- `evaluate("8 {L | 50 km}", ctx)` → `unknown unit 'L | 50 km'`

## Flow 3: Cancel kilometres without dissolving litres

**Actor:** library caller
**Precondition:** Flow 2

**Steps:**

1. `evaluate("8 {L | 100 km} * 100 km", ctx)` → `#Elex.Quantity<8 L>`
2. `validate("8 {L | 100 km} * 100 km", ctx)` → `{:ok, #Elex.Dimension<length^3>}`
3. `evaluate("1 / 8 {L | 100 km}", ctx)` → `#Elex.Quantity<12.5 km | L>`
4. `validate("1 / 8 {L | 100 km}", ctx)` → `{:ok, #Elex.Dimension<length | volume>}`
5. `evaluate("1 L + 1 m^3", ctx)` → `#Elex.Quantity<1001 L>`
6. `evaluate("1 m^3 + 1 L", ctx)` → `#Elex.Quantity<1.001 m^3>`
7. `evaluate("1 L / 1 m^3", ctx)` → decimal `0.001`
8. `validate("1 L", ctx)` → `{:ok, #Elex.Dimension<length^3>}`
9. `validate("1 L + 1 m^3", ctx)` → `{:ok, #Elex.Dimension<length^3>}`

**Error paths:**

- `evaluate("1 L + 1 km", ctx)` → `cannot add volume and length`
- `evaluate("1 / 0 {L | 100 km}", ctx)` → `division by zero`

## Flow 4: Miles per gallon on the nominal dimension

**Actor:** library caller
**Precondition:** Fixture, with `:fuel` created as `additive: false`, default `L | km`. `mile` converts with `"value * 1609.344"`. `L | km` and `L | 100 km` are registered. `gallon` has `derivable: false`.

**Steps:**

1. `Catalog.add_unit(catalog, :fuel, "mile | gallon", "3.785411784 / 1.609344 / value")` → `{:ok, catalog}`
2. `Context.put_units` → `{:ok, ctx}`
3. `evaluate("8 {L | 100 km}", ctx, unit: "mile | gallon")` → `#Elex.Quantity<29.40182291666666666666666666666666 mile | gallon>`
4. `validate("8 {mile | gallon}", ctx)` → `{:ok, #Elex.Dimension<volume | length>}`

**Error paths:**

- The same reciprocal on `additive: true` → `reciprocal conversion for 'mile | gallon' is not allowed on additive category :fuel`
- `"mile | gallon"` with `"value"` → `formula 'mile | gallon' does not match the category dimension`

## Flow 5: Powers of length still reduce

**Actor:** library caller
**Precondition:** `:length` default `m`. `:volume` formula `length * length * length`, default `m^3`, with `m^3` registered at `"value"` and `derivable:` omitted. `:area` formula `length * length`, default `m^2`, with `m^2` registered at `"value"`. No `derivable: false` unit is required.

**Steps:**

1. `evaluate("1 m * 1 m * 1 m", ctx)` → `#Elex.Quantity<1 m^3>` with monomial `%{"m" => 3}`
2. `validate("1 m * 1 m * 1 m", ctx)` → `{:ok, #Elex.Dimension<length^3>}`
3. `evaluate("1 m^3 / 1 m", ctx)` → `#Elex.Quantity<1 m^2>`
4. `validate("1 m^3 / 1 m", ctx)` → `{:ok, #Elex.Dimension<length^2>}`
5. On the Flow 1 catalog, `Catalog.add_unit(catalog, :fuel, "m^3 | m", "value")` → `formula 'm^3 | m' repeats category :length in the numerator and denominator`

**Error paths:**

- On the Flow 1 catalog, `"cm^3 | m"` on `:fuel` → `formula 'cm^3 | m' repeats category :length in the numerator and denominator`

## Flow 6: Hectare still expands

**Actor:** library caller
**Precondition:** Hectare catalog from the units guide. `ha` omits `derivable:`.

**Steps:**

1. `evaluate("1 ha / 1 m", ctx)` → `#Elex.Quantity<10000 m>`
2. `validate("1 ha / 1 m", ctx)` → `{:ok, #Elex.Dimension<length>}`

**Error paths:**

- None. This flow is a regression.

## Flow 7: Kilowatt-hour per 100 km needs no mark

**Actor:** library caller
**Precondition:** None of the volume fixture. `:energy` is a base category, default `kWh`, unit `kWh` at `"value"`. `:length` default `km`, unit `km` at `"value"`. `:consumption` formula `energy | length`, default `kWh | km`.

**Steps:**

1. `Catalog.add_unit(catalog, :consumption, "kWh | km", "value")` → `{:ok, catalog}`
2. `Catalog.add_unit(catalog, :consumption, "kWh | 100 km", "value / 100")` → `{:ok, catalog}`
3. `evaluate("8 {kWh | 100 km} * 100 km", ctx)` → `#Elex.Quantity<8 kWh>`

**Error paths:**

- `"kWh | 100 km"` with `"value"` → `unit 'kWh | 100 km' conversion does not match the scale of its component units`
