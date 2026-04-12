---
id: std-math
title: math
---

# `math`

`math` provides numeric constants and scalar math helpers.

## `math.pi`

The mathematical constant pi.

Use this for trigonometry, geometry, and numeric calculations that need a standard value of π.

## `math.huge`

A very large numeric sentinel value.

This is useful when you need an infinity-like upper bound in numeric code.

## `math.abs(value)`

Returns the absolute value of a number.

Negative values become positive; non-negative values are returned unchanged.

## `math.floor(value)`

Rounds a number downward to the nearest integer.

This is useful when you need stable integer buckets or lower bounds.

## `math.ceil(value)`

Rounds a number upward to the nearest integer.

This is useful when you need upper bounds or whole-number allocation sizes.

## `math.round(value)`

Rounds a number to the nearest integer.

The current implementation uses a simple half-up strategy based on `floor(value + 0.5)`.

## `math.sqrt(value)`

Returns the square root of a number.

Use this for distance, geometry, and general numeric work.

## `math.pow(base, exponent)`

Raises a base to a power.

This is equivalent to `base ^ exponent`, but exposed as a module helper.

## `math.min(a, b)`

Returns the smaller of two values.

This is useful when clamping or picking a lower bound.

## `math.max(a, b)`

Returns the larger of two values.

This is useful when clamping or picking an upper bound.

## `math.clamp(value, minValue, maxValue)`

Constrains a number to a given range.

If the value is below the minimum it returns the minimum, and if it is above the maximum it returns the maximum.

## `math.sin(value)`

Returns the sine of an angle.

Angles are interpreted using the host math library conventions.

## `math.cos(value)`

Returns the cosine of an angle.

This is useful in geometry, animation, and coordinate transforms.

## `math.tan(value)`

Returns the tangent of an angle.

Use this where tangent-based ratios are required.

## `math.asin(value)`

Returns the inverse sine of a value.

This converts from a ratio back into an angle.

## `math.acos(value)`

Returns the inverse cosine of a value.

This converts from a ratio back into an angle.

## `math.atan(value)`

Returns the inverse tangent of a value.

This is useful when deriving an angle from a slope or ratio.

## `math.random(minValue = nil, maxValue = nil)`

Returns a random value using the host random generator.

With no arguments it returns a fractional value. With one or two bounds it behaves like the host integer random helper.

## `math.seed(seed)`

Seeds the random number generator.

Use this when you want reproducible pseudo-random output in tests or deterministic tools.
