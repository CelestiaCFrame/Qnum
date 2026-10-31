--[[
Qnum
====
Current version: 1.2
--------------------
A large number library for handling huge numbers beyond 1e308.

This library limit is `10 ^^ (10 ^ 308)` or `E1#1e308`

Usage examples:
```lua
    local Qnum = require("Qnum")
    local number = Qnum.new(10)
    print(number)
```

Qnum functions: `new, fromSuperLogarithm, ToString, add, sub, mul, div, pow, tetr, exp, cmp, min, max, fact, gamma, sqrt, isFinite, root, abs, ToNumber`
]]

local Qnum = {}
Qnum.__index = Qnum

function Qnum.new(n)
    assert(type(n) == "number" or type(n) == "string", string.format("Invalid argument #1 to 'new' (number or string expected, got %s)", type(n)))
    if n == nil then
        n = 0
    end

    local self = setmetatable({}, Qnum)

    if n == math.huge then
        self.slog = math.huge
        return self
    elseif n == -math.huge then
        self.slog = -math.huge
        return self
    end

    local BigNumber = false

    if type(n) == "string" then
        local _, count_e = string.gsub(n, "[eE]", "e")
        assert(count_e <= 1, string.format("Unsupported format: %s", n))
        local exp_str = n:match("[eE](.+)")
        if exp_str then
            local base_str = n:sub(1, n:find("[eE]") - 1)
            local base = tonumber(base_str)
            local exponent = tonumber(exp_str)
            assert(base and exponent, "Invalid format for big number")

            --[[
            if exponent >= 10 then
                BigNumber = true
            end
            ]]

            BigNumber = true
            n = exponent + math.log(base, 10)
        else
            n = tonumber(n)
        end
    end

    local function computeSlog(x)
        if x < 1 then
            return x - 1
        end
        local count = 0
        while x >= 10 do
            x = math.log(x, 10)
            count = count + 1
        end
        return count + math.log(x, 10)
    end

    if BigNumber then
        self.slog = 1 + computeSlog(n)
    else
        self.slog = computeSlog(n)
    end

    return self
end

---@generic Qnum: table
---@return Qnum
---@param n number
---Creates a new Qnum type from SuperLogarithm.
function Qnum.fromSuperLogarithm(n)
    assert(type(n) == "number", string.format("Invalid argument #1 to 'fromSuperLogarithm' (number expected, got %s)", type(n)))
    
    local self = setmetatable({}, Qnum)
    self.slog = n

    return self
end

---@return string | number
---Returns the string format for the Qnum.
function Qnum:ToString()
    if self.slog == math.huge then return "Infinity" end
    if self.slog == -math.huge then return "-Infinity" end
    local ret
    if self.slog < 0 then
        ret = math.floor((self.slog + 1) * 1000) / 1000

        if ret == math.floor(ret) then
            ret = tostring(ret) .. "000"
        end
    elseif self.slog < 1 then
        ret = math.floor((10 ^ self.slog) * 1000) / 1000
        if ret == math.floor(ret) then
            ret = tostring(ret) .. "000"
        end
    elseif self.slog < 1 + math.log(3, 10) then
        ret = math.floor(100 * (10 ^ (10 ^ (self.slog % 1)))) / 100

        if ret == math.floor(ret) then
            ret = tostring(ret) .. "000"
        end
    elseif self.slog < 1 + math.log(6, 10) then
        ret = math.floor(10 ^ (10 ^ (self.slog % 1)))
    elseif self.slog < 2 then
        ret = math.floor(100 * (10 ^ ((10 ^ (self.slog % 1)) % 1))) / 100

        if ret == math.floor(ret) then
            ret = tostring(ret) .. "00"
        end

        ret = ret .. "e" .. math.floor(10 ^ (self.slog % 1))
    elseif self.slog < 2 + math.log(5, 10) then
        ret = math.floor(100 * (10 ^ ((10 ^ (10 ^ (self.slog % 1))) % 1))) / 100
    
        if ret == math.floor(ret) then
            ret = tostring(ret) .. "00"
        end

        ret = ret .. "e" .. math.floor(10 ^ (10 ^ (self.slog % 1)))
    elseif self.slog < 7 + math.log(5, 10) then
        if self.slog % 1 < math.log(5, 10) then
            ret = math.floor(100 * (10 ^ ((10 ^ (10 ^ (self.slog % 1))) % 1))) / 100

            if ret == math.floor(ret) then
                ret = tostring(ret) .. "00"
            end
    
            ret = ret .. "e" .. math.floor(10 ^ (10 ^ (self.slog % 1)))
            for i = 1, math.floor(self.slog) - 2 do
                ret = "e" .. ret
            end
        else
            ret = math.floor(100 * (10 ^ ((10 ^ (self.slog % 1)) % 1))) / 100
        
            if ret == math.floor(ret) then
                ret = tostring(ret) .. "00"
            end
    
            ret = ret .. "e" .. math.floor(10 ^ (self.slog % 1))
            for i = 1, math.floor(self.slog) - 1 do
                ret = "e" .. ret
            end
        end
    else
        ret = math.floor(1000 * (10 ^ (self.slog % 1))) / 1000

        if ret == math.floor(ret) then
            ret = tostring(ret) .. "00"
        end

        ret = "E" .. ret .. "#" .. math.floor(self.slog)
    end

    return ret
end

function Qnum.add(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end

    local ret
    if y.slog > x.slog then
        ret = Qnum.add(y, x).slog
    else
        local A = math.floor(x.slog)
        local B = math.floor(y.slog)
        local difference = A - B

        if B == -1 then
            if A == -1 then
                ret = x.slog + y.slog + 1
                if ret > 0 then
                    ret = math.log(1 + ret, 10)
                end
            elseif A == 0 then
                ret = math.log((10 ^ x.slog) + y.slog + 1, 10)
                if ret > 1 then
                    ret = 1 + math.log(ret, 10)
                end
            elseif A == 1 then
                ret = 1 + (math.log(math.log((10 ^ (10 ^ (x.slog - 1))) + y.slog + 1, 10), 10))
                if ret > 2 then
                    ret = 2 + math.log(ret - 1, 10)
                end
            elseif A > 1.5 then
                ret = x.slog
            end
        elseif B == 0 then
            if A == 0 then
                ret = math.log((10 ^ x.slog) + (10 ^ y.slog), 10)
                if ret > 1 then
                    ret = 1 + math.log(ret, 10)
                end
            elseif A == 1 then
                ret = 1 + math.log(math.log((10 ^ (10 ^ (x.slog - 1))) + (10 ^ y.slog), 10), 10)
                if ret > 2 then
                    ret = 2 + math.log(ret - 1, 10)
                end
            elseif A > 1.5 then
                ret = x.slog
            end
        elseif B == 1 then
            if A == 1 then
                ret = 1 + math.log(math.log((10 ^ (10 ^ (x.slog - 1))) + (10 ^ (10 ^ (y.slog - 1))), 10), 10)
                if ret > 2 then
                    ret = 2 + math.log(ret - 1, 10)
                end
            elseif A == 2 then
                ret = 2 + math.log(math.log((10 ^ (10 ^ (x.slog - 2))) + math.log(1 + 10 ^ ((10 ^ (y.slog - 1)) - (10 ^ (10 ^ x.slog - 2))), 10), 10), 10)
                if ret > 3 then
                    ret = 3 + math.log(ret - 2, 10)
                end
            elseif A > 2.5 then
                ret = x.slog
            end
        elseif B == 2 then
            if A == 2 then
                ret = 2 + math.log(math.log((10 ^ (10 ^ (x.slog - 2)) + math.log(1 + 10 ^ ((10 ^ (10 ^ (y.slog - 2))) - (10 ^ (10 ^ (x.slog - 2)))), 10)), 10), 10)
                if ret > 3 then
                    ret = 3 + math.log(ret - 2, 10)
                end
            elseif A > 2.5 then
                ret = x.slog
            end
        elseif B > 2.5 then
            ret = x.slog
        end
    end

    return Qnum.fromSuperLogarithm(ret)
end

function Qnum.sub(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end

    local A = math.floor(x.slog)
    local B = math.floor(y.slog)
    local guesser = 0
    local adder = 0
    local ret

    if A > 2.5 then
        ret = x.slog
    else
        guesser = -1
        adder = 4
        for i = 1, 30 do
            adder = adder / 2
            guesser = guesser + adder
            ret = Qnum.add(y, Qnum.fromSuperLogarithm(guesser)).slog
            if ret > x.slog then
                guesser = guesser - adder
            end
        end

        if guesser == -1 then
            guesser = guesser + adder
        end

        ret = guesser
    end

    return Qnum.fromSuperLogarithm(ret)
end

function Qnum.mul(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end
    local ret
    local re

    if y.slog > x.slog then
        ret = Qnum.mul(y, x).slog
    elseif math.floor(x.slog) > 3.5 then
        ret = x.slog
    elseif y.slog > 0 then
        ret = Qnum.add(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(y.slog - 1)).slog
        ret = ret + 1
    elseif x.slog > 0 then
        re = math.log(1 / (1 + y.slog), 10)

        if re > 1 then
            re = 1 + math.log(re, 10)
        end

        if re > 2 then
            re = 2 + math.log(re - 1, 10)
        end

        ret = Qnum.sub(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(re - 1)).slog
        ret = ret + 1

        if re - 1 > x.slog - 1 then
            ret = Qnum.sub(Qnum.fromSuperLogarithm(re - 1), Qnum.fromSuperLogarithm(x.slog - 1)).slog
            ret = ret + 1
            if ret < 1 then
                ret = 1 / (10 ^ ret) - 1
            elseif ret < 2 then
                ret = 1 / (10 ^ 10 ^ (ret - 1)) - 1
            else
                ret = 1 / (10 ^ 10 ^ 10 ^ (ret - 2)) - 1
            end
        end
    else
        ret = (x.slog + 1) * (y.slog + 1) - 1
    end

    return Qnum.fromSuperLogarithm(ret)
end

function Qnum.div(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end
    local ret
    local re
    if math.floor(x.slog) > 3.5 then
        ret = x.slog
    elseif y.slog > 0 then
        ret = Qnum.sub(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(y.slog - 1)).slog
        ret = ret + 1
        if y.slog > x.slog then
            ret = Qnum.sub(Qnum.fromSuperLogarithm(y.slog - 1), Qnum.fromSuperLogarithm(x.slog - 1)).slog
            ret = ret + 1
            if ret < 1 then
                ret = 1 / (10 ^ ret) - 1
            elseif ret < 2 then
                ret = 1 / (10 ^ 10 ^ (ret - 1)) - 1
            else
                ret = 1 / (10 ^ 10 ^ 10 ^ (ret - 2)) - 1
            end
        end
    elseif x.slog > 0 then
        re = math.log(1 / (1 + y.slog), 10)
        if re > 1 then
            re = 1 + math.log(re, 10)
        end

        if re > 2 then
            re = 2 + math.log(re - 1, 10)
        end

        ret = Qnum.add(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(re - 1)).slog
        ret = ret + 1
    else
        re = (x.slog + 1) / (y.slog + 1) - 1
        if re > 0 then
            re = math.log(re + 1, 10)
        end

        if re > 1 then
            re = 1 + math.log(re, 10)
        end

        if re > 2 then
            re = 2 + math.log(re - 1, 10)
        end

        ret = re
    end

    return Qnum.fromSuperLogarithm(ret)
end

function Qnum.pow(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end
    local ret = Qnum.mul(Qnum.fromSuperLogarithm(x.slog - 1), y)
    ret.slog = ret.slog + 1
    return ret
end

function Qnum.tetr(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    assert(not (getmetatable(y) == Qnum), "Unsupported format: y cannot be type of Qnum")
    if x.slog == math.huge then return x end
    if y == math.huge then return y end
    local ret
    local height
    if x.slog == 0 then
        ret = 0
    else
        height = y
        if y == 0 then
            ret = 0
        elseif y == 1 then
            ret = x.slog
        else
            ret = 0
            repeat
                if ret > 10 then
                    ret = ret + height
                    height = 0
                else
                    ret = Qnum.pow(x, Qnum.fromSuperLogarithm(ret)).slog
                    height = height - 1
                end
            until height < 1
        end
    end

    return Qnum.fromSuperLogarithm(ret)
end

function Qnum.exp(x)
    return Qnum.pow(Qnum.new(math.exp(1)), x)
end

function Qnum.__unm(x)
    if type(x) == "number" then x = Qnum.new(x) end
    if x.slog == math.huge then return Qnum.new(-math.huge) end
    return Qnum.new(-x:ToNumber())
end

function Qnum.__add(x, y)
    return Qnum.add(x, y)
end

function Qnum.__sub(x, y)
    return Qnum.sub(x, y)
end

function Qnum.__mul(x, y)
    return Qnum.mul(x, y)
end

function Qnum.__div(x, y)
    return Qnum.div(x, y)
end

function Qnum.__pow(x, y)
    return Qnum.pow(x, y)
end

function Qnum.__tostring(x)
    return x:ToString()
end

function Qnum.__eq(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    return x.slog == y.slog
end

function Qnum.__lt(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    return x.slog < y.slog
end

function Qnum.__le(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    return x.slog <= y.slog
end

function Qnum.cmp(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    if x > y then
        return ">"
    elseif x < y then
        return "<"
    elseif x == y then
        return "=="
    end
end

function Qnum.min(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    return math.min(x.slog, y.slog)
end

function Qnum.max(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    return math.max(x.slog, y.slog)
end

function Qnum.fact(x)
    if type(x) == "number" then x = Qnum.new(x) end
    if x.slog == math.huge then return x end
    return (2 * Qnum.pi * x) ^ 0.5 * (x / Qnum.e) ^ x
end

function Qnum.gamma(x)
    if type(x) == "number" then x = Qnum.new(x) end
    if x.slog == math.huge then return x end
    return Qnum.fact(x - 1)
end

function Qnum.sqrt(x)
    if type(x) == "number" then x = Qnum.new(x) end
    if x.slog == math.huge then return x end
    return x ^ 0.5
end

function Qnum.isFinite(x)
    if type(x) == "number" then x = Qnum.new(x) end
    return not (x.slog == math.huge)
end

function Qnum.root(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end
    return x ^ (1 / y)
end

function Qnum.abs(x)
    if type(x) == "number" then x = Qnum.new(x) end
    if x.slog == math.huge then return x end
    if x.slog == -math.huge then return -x end

    if x.slog >= 0 then
        return x
    else
        return Qnum.new(-x.slog - 1)
    end
end

function Qnum:ToNumber()
    if self.slog > Qnum.new(1e308).slog then
        error("Unsupported number: number is too large")
    else
        return tonumber(self:ToString())
    end
end

Qnum.pi = Qnum.new(math.pi)
Qnum.e = Qnum.new(math.exp(1))
Qnum._VERSION = "Qnum 1.2"

local function Protect(table)
    local proxy = {}
    setmetatable(proxy, {
        __index = table,
        __newindex = function()
            error("Attempt to modify a frozen table", 2)
        end,
        __metatable = false
    })
    return proxy
end

for i = 1, 10 do
    print(Qnum.new("1e" .. tostring(i)))
end

Qnum = Protect(Qnum)
return Qnum
