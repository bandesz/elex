# User flows

Canonical behaviour for percent values. Actor is always a **library caller**.

`Percent 50` means `%Elex.Percent{value: #Decimal<50>}` and the value compares equal with `Decimal.equal?/2`. `Decimal 50` means `#Decimal<50>`. A quantity result keeps the left-hand unit. Context is `Elex.new_context/0` unless a step names a catalog.

## Flow 1: Percent literals

**Precondition:** context with or without a unit catalog

**Steps:**

1. `evaluate("50%")` → `{:ok, Percent 50}`
2. `evaluate("50 %")` and `evaluate("50% ")` → `Percent 50`
3. `evaluate("1e2%")` → `Percent 100` (inspect `#Elex.Percent<100%>`)
4. `evaluate("-10%")` → `Percent -10`
5. `evaluate("0%")`, `evaluate("150%")`, `evaluate("-150%")` → `Percent 0`, `Percent 150`, `Percent -150`
6. `validate("50%")` → `{:ok, :percent}` with or without a catalog
7. `Parser.parse("50%", ctx)` → `{:ok, {:percent, Decimal.new("50")}, :percent}`
8. `Parser.parse("-10%", ctx)` → `{:ok, {:percent, Decimal.new("-10")}, :percent}` (one literal; the minus is part of the number)
9. `Parser.parse("-(50%)", ctx)` → `{:ok, {:-, {:percent, Decimal.new("50")}}, :percent}`
10. `evaluate("-(50%)")` → `Percent -50`
11. `Parser.parse("50%", ctx, validate: false)` → `{:ok, {:percent, Decimal.new("50")}, nil}`
12. `extract_variables("100 * rate + 50%", ctx)` → `{:ok, ["rate"]}`

**Error paths:**

- `"(10+20)%"`, `"rate%"`, and `"50%%"` → `unexpected '%'`
- `"50%cm"` → `unexpected 'cm'`
- `".5%"` → the same parse error as `".5"`

## Flow 2: Scale a number or a quantity

**Precondition:** length catalog with `cm` and `mm` when the expression uses units (`m` default, `cm` = `value / 100`, `mm` = `value / 1000`)

**Steps:**

1. `evaluate("100 * 50%")` and `evaluate("50% * 100")` → `Decimal 50`
2. `evaluate("2 * 50%")` → `Decimal 1`
3. `evaluate("100cm * 50%")` and `evaluate("50% * 100cm")` → quantity `50`, unit `cm`
4. `evaluate("100cm * -10%")` → quantity `-10`, unit `cm`
5. `evaluate("100 * 50% * 50%")` → `Decimal 25`
6. `evaluate("100cm * 50%", ctx, unit: "mm")` → quantity `500`, unit `mm`
7. `validate("100 * 50%")` → `{:ok, :decimal}`
8. `validate("100cm * 50%")` → `{:ok, %Elex.Dimension{monomial: %{length: 1}}}`

## Flow 3: Add, subtract, and multiply percents

**Steps:**

1. `evaluate("10% + 20%")` → `Percent 30`
2. `evaluate("30% - 20%")` → `Percent 10`
3. `evaluate("20% - 30%")` → `Percent -10`
4. `evaluate("100% + -10%")` → `Percent 90`
5. `evaluate("50% * 50%")` → `Percent 25`
6. `evaluate("50% * 50% * 50%")` → `Percent 12.5`
7. `validate("10% + 20%")` and `validate("50% * 50%")` → `{:ok, :percent}`

**Error paths:**

- `"10% + 1"` → `cannot add percent and number`
- `"1 + 10%"` → `cannot add number and percent`
- `"100cm + 50%"` → `cannot add length and percent`
- `"50% + 100cm"` → `cannot add percent and length`
- `"10% - 1"` → `cannot subtract number from percent`
- `"1 - 10%"` → `cannot subtract percent from number`
- `"100cm - 50%"` → `cannot subtract length and percent`
- `"50% - 100cm"` → `cannot subtract percent and length`
- `"10% + 0"` and `"0 + 10%"` → `cannot add percent and number` and `cannot add number and percent`

## Flow 4: Division and remainder

**Error paths:**

- `"100% / 2"`, `"2 / 100%"`, `"100% / 50%"`, `"100cm / 50%"`, and `"50% / 100cm"` → `cannot divide with a percent`
- `"mod(10%, 3)"` → `mod function expects number arguments, got percent`

## Flow 5: Comparisons

**Steps:**

1. `evaluate("50% > 10%")` → `{:ok, true}`
2. `evaluate("10% > 0%")` and `evaluate("-10% < 0%")` → `{:ok, true}`
3. `evaluate("50% == 50%")` → `{:ok, true}`
4. `evaluate("100% > 0")`, `evaluate("0 < 100%")`, `evaluate("0% == 0")` → `{:ok, true}`, `{:ok, true}`, `{:ok, true}`
5. `evaluate("100% == 0")` → `{:ok, false}`
6. `0.0`, `0.00`, `0e0`, `-0`, `(0)`, and `--0` behave the same as `0` next to a percent
7. `validate("100% > 0")` → `{:ok, :boolean}`

**Error paths:**

- `"100% > 1"` and `"50% == 0.5"` → `cannot compare percent and number`
- `"50% > 10cm"` → `cannot compare percent and length`
- `"100% > count"` when `count` is a decimal variable, including a variable whose value is zero → `cannot compare percent and number`
- `"100% > (1 - 1)"` → `cannot compare percent and number`

## Flow 6: `min`, `max`, `clamp`, `between`

**Steps:**

1. `min(30%, 10%, 20%)` → `Percent 10`
2. `max(30%, 10%)` → `Percent 30`
3. `clamp(150%, 0%, 100%)` → `Percent 100`
4. `clamp(-150%, -100%, 0%)` → `Percent -100`
5. `min(10%, 0)` and `min(0, 10%)` → `Percent 0`
6. `max(10%, 0)` → `Percent 10`
7. `clamp(-5%, 0, 100%)` → `Percent 0`
8. `between(15%, 10%, 20%)` and `between(10%, 10%, 20%)` → `true`
9. `between(9%, 10%, 20%)` → `false`
10. `between(5%, 0, 100%)` → `true`
11. `validate` of `min(30%, 10%)` → `{:ok, :percent}`; `validate` of `between(15%, 10%, 20%)` → `{:ok, :boolean}`

**Error paths:**

- `min(10%, 1)` → `cannot mix percent and number`
- `between(15%, 10%, 1)` → `cannot mix percent and number`

## Flow 7: `if` and `coalesce`

**Steps:**

1. `if(true, 10%, 20%)` → `Percent 10`
2. `if(false, 10%, 20%)` → `Percent 20`
3. `if(true, 10%, 0)` → `Percent 10`
4. `if(false, 10%, 0)` → `Percent 0`
5. `if(100% > 0, 100%, 0)` → `Percent 100`
6. `coalesce(null, 10%)` → `Percent 10`
7. `coalesce(null, 0, 10%)` → `Percent 0`
8. `coalesce(null, 10%, 0)` → `Percent 10`
9. `if(true, 10%, pow(0%, -1))` → `Percent 10` (the unused branch is a percent, so validation succeeds and it errors only when evaluated). `if(true, 10%, 1 / 0)` is the same type error as mixing a percent with a number, because `1 / 0` validates as a number.

**Error paths:**

- `if(true, 10%, 1)` → `if branches must have the same type, got percent and number`
- `coalesce(10%, 1)` → `coalesce arguments must have the same type, got percent and number`

## Flow 8: `abs`, `round`, `floor`, `ceil`

**Steps:**

1. `abs(-10%)` → `Percent 10`
2. `round(10.4%)` → `Percent 10`
3. `round(10.5%)` → `Percent 11`
4. `round(-10.5%)` → `Percent -11`
5. `floor(10.9%)` → `Percent 10`
6. `floor(-10.1%)` → `Percent -11`
7. `ceil(10.1%)` → `Percent 11`
8. `ceil(-10.1%)` → `Percent -10`
9. `validate("abs(-10%)")` → `{:ok, :percent}`

Rounding uses the same `Decimal` operation as the number form of that function, applied to percent points: `round/1`, `Decimal.round(points, 0, :floor)`, and `Decimal.round(points, 0, :ceiling)`.

**Error paths:**

- `concat(10%, "x")` → `concat function expects string arguments, got percent`

## Flow 9: `pow` and `sqrt`

**Steps:**

1. `pow(50%, 2)` → `Percent 25`
2. `pow(50%, 3)` → `Percent 12.5`
3. `pow(-50%, 2)` → `Percent 25`
4. `pow(-50%, 3)` → `Percent -12.5`
5. `pow(50%, 0)` and `pow(0%, 0)` → `Percent 100`
6. `pow(50%, 1)` → `Percent 50`
7. `pow(50%, -1)` → `Percent 200`
8. `pow(50%, 0.5)` → a percent whose points equal `Decimal.mult(pow(0.5, 0.5), 100)` after the same normalization decimal `pow` uses
9. `validate("pow(50%, 2)")` → `{:ok, :percent}`

**Error paths:**

- `pow(2, 50%)` and `pow(50%, 50%)` → `pow function expects a number exponent, got percent`
- `pow(0%, -1)` → the same error as `pow(0, -1)`
- `sqrt(25%)`, `sqrt(0%)`, `sqrt(50%)`, and `sqrt(-25%)` → `sqrt function expects a number argument, got percent` from both validate and evaluate

## Flow 10: Variables

**Steps:**

1. `add_variable!(ctx, "rate", %Elex.Percent{value: Decimal.new("50")})` succeeds and stores type `:percent`
2. `evaluate("100 * rate", ctx)` → `Decimal 50`
3. `evaluate("rate + 10%", ctx)` → `Percent 60`
4. `validate("rate", ctx)` → `{:ok, :percent}`
5. A decimal variable `50` stays a number: `evaluate("100 * rate", ctx)` → `Decimal 5000`

**Error paths:**

- `add_variable(ctx, "rate", %Elex.Percent{value: 50})` → `{:error, "variable 'rate' percent value must be a decimal"}`
- `add_variable(ctx, "rate", %Elex.Percent{value: Decimal.new("50")}, category: :length)` → `{:error, "variable 'rate' has category length but value is unitless"}`

## Flow 11: Autocomplete and invert

**Precondition:** a length catalog that already completes `10m` to `m` and `mm`

**Steps:**

1. `autocomplete("10m", 3, ctx)` still suggests `m` and `mm`
2. `autocomplete("10%", 3, ctx)` → `{:ok, %{suggestions: []}}` and does not raise
3. `Inverter.invert` on an AST that contains `{:percent, _}` → `{:error, "cannot invert an expression that contains a percent"}`, including a lone `{:percent, _}` and `rate + 10%`
4. `Inverter.invert` of `rate + 1` is unchanged

## Flow 12: Ash, `unit:`, and `category:`

**Precondition:** length catalog when `category:` or `unit:` is set. Ash steps use `Elex.AshValidation`.

**Steps:**

1. `expected_type: :percent` accepts `"50%"` and `"10% + 20%"` with or without a unit catalog
2. `expected_type: :percent` does not require a catalog (`init` succeeds on `Elex.new_context()`)

**Error paths:**

- `"1 + 2"` with `expected_type: :percent` → attribute message `must return percent, but returns decimal`
- `"50%"` with `expected_type: :decimal` → `must return decimal, but returns percent`
- `validate("50%", ctx, category: :length)` → `length was expected, got percent`
- `evaluate("50%", ctx, unit: "cm")` when `cm` is registered → `cannot convert percent to a unit`

## Flow 13: `inc` and `dec`

`inc(value, rate)` is `value * (100% + rate)`. `dec(value, rate)` is `value * (100% - rate)`. `rate` must be a percent.

**Precondition:** length catalog with `cm` when the expression uses units (`m` default, `cm` = `value / 100`). Temperature catalog when the expression uses `C`.

**Steps:**

1. `evaluate("inc(100, 10%)")` → `Decimal 110`
2. `evaluate("dec(100, 10%)")` → `Decimal 90`
3. `evaluate("inc(100cm, 10%)")` → quantity `110`, unit `cm` (`110cm`)
4. `evaluate("inc(50%, 10%)")` → `Percent 55` (`55%`)
5. `validate("inc(100, 10%)")` → `{:ok, :decimal}`; `validate("dec(50%, 10%)")` → `{:ok, :percent}`

**Error paths:**

- `"inc(100, 10)"` → `inc function expects a percent rate, got decimal`
- `"dec(100, 0)"` → `dec function expects a percent rate, got decimal`
- `"inc(20C, 10%)"` → `cannot use non-additive temperature with 'inc'`
