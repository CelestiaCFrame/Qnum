# Qnum

### Current version: 1.2

**A large number library for Lua that handles numbers far beyond the standard `1e308` limit.**</br>
**This was inspired by [break_infinity.js](https://github.com/Patashu/break_infinity.js)**

---

## Features

- Uses Super-Logarithm (`slog`) representation internally.
- Supports scientific notation and extended exponent notation.
- Basic arithmetic operations, Factorial, gamma, square root, exponentiation and tetration.
- Number comparison.
- Conversion to strings and standard Lua numbers.
- Positive and negative infinity support.

## Number Limit

The representation limit of Qnum is: 

10 ↑↑ 10<sup>308</sup>

which is a power tower of 10s with 10<sup>308</sup> levels.

## Installation

Place `Qnum.lua` in your project directory.

Import it using:

```lua
local Qnum = require("Qnum")
```

### Example

```lua
local Qnum = require("Qnum")

local a = Qnum.new("1e100")
local b = Qnum.new("1e200")

print(a + b)
print(a * b)
print(a ^ 2)
```

## Number Representation

Qnum stores numbers internally using a Super-Logarithm value called `slog`.

Instead of storing the original number directly, Qnum transforms it into a representation that allows much larger values to be handled.

You can also create a Qnum object directly from a Super-Logarithm value:

```lua
local number = Qnum.fromSuperLogarithm(2)

print(number)
```

### Supported Input Formats

Qnum accepts both Lua numbers and strings.

```lua
Qnum.new(100)
Qnum.new("100")
Qnum.new("1e100")
Qnum.new("1e1000")
```

## Complete Function List

```lua
Qnum.new(n)
Qnum.fromSuperLogarithm(n)

Qnum:ToString()
Qnum:ToNumber()

Qnum.add(x, y)
Qnum.sub(x, y)
Qnum.mul(x, y)
Qnum.div(x, y)
Qnum.pow(x, y)
Qnum.tetr(x, y)
Qnum.exp(x)

Qnum.cmp(x, y)
Qnum.min(x, y)
Qnum.max(x, y)

Qnum.fact(x)
Qnum.gamma(x)
Qnum.sqrt(x)
Qnum.root(x, y)
Qnum.abs(x)

Qnum.isFinite(x)
```
