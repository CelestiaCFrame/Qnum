--[[
Qnum
====
Current version: 1.2
--------------------------------------------------------------
A large number library for handling huge numbers beyond 1e308.

This library limit is `10 ^^ (10 ^ 308)` or `E1#1e308`

Usage example:
    local Qnum = require("Qnum")
    local a = Qnum.new("4")
    local b = Qnum.new("-1")
    print(a ^ b) -- Outputs: 0.25

Qnum functions: new, fromSuperLogarithm, ToString, add, sub, mul, div, pow, tetr, exp, cmp, min, max, fact, gamma, sqrt, isFinite, root, abs, ToNumber
]]

local Qnum = {}
Qnum.__index = Qnum

function Qnum.new(n)
    if n == nil then
        n = 0
    end
    assert(type(n) == "number" or type(n) == "string", string.format("Invalid argument #1 to 'new' (number or string expected, got %s)", type(n)))

    local sign = 1
    if type(n) == "number" then
        if n < 0 then
            sign = -1
            n = -n
        end
    elseif type(n) == "string" then
        n = n:gsub("^%s+", "")
        if n:sub(1, 1) == "-" then
            sign = -1
            n = n:sub(2)
        elseif n:sub(1, 1) == "+" then
            n = n:sub(2)
        end
    end

    local self = setmetatable({}, Qnum)
    self.sign = sign

    if n == math.huge or n == "inf" or n == "Infinity" then
        self.slog = math.huge
        return self
    elseif n == -math.huge then
        self.slog = math.huge
        self.sign = -1
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
            BigNumber = true
            n = exponent + math.log(base, 10)
        else
            n = tonumber(n)
            assert(n, "Invalid number format")
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
---@param sign number?
---Creates a new Qnum type from SuperLogarithm and sign.
function Qnum.fromSuperLogarithm(n, sign)
    assert(type(n) == "number", string.format("Invalid argument #1 to 'fromSuperLogarithm' (number expected, got %s)", type(n)))
    
    local self = setmetatable({}, Qnum)
    self.slog = n
    self.sign = sign or 1

    return self
end

---@return string | number
---Returns the string format for the Qnum.
function Qnum:ToString()
    if self.slog == math.huge then 
        return (self.sign == -1) and "-Infinity" or "Infinity" 
    end
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

    if self.sign == -1 and ret ~= "0" and ret ~= "000" then
        ret = "-" .. ret
    end

    return ret
end

local function compare_mag(x, y)
    if x.slog == y.slog then return 0 end
    return x.slog > y.slog and 1 or -1
end

local function mag_add(x, y)
    if x.slog == math.huge then return x.slog end
    if y.slog == math.huge then return y.slog end

    local ret
    if y.slog > x.slog then
        ret = mag_add(y, x)
    else
        local A = math.floor(x.slog)
        local B = math.floor(y.slog)

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

    return ret
end

local function mag_sub(x, y)
    if x.slog == math.huge then return x.slog end
    if y.slog == math.huge then return -math.huge end

    local A = math.floor(x.slog)
    local guesser = -1
    local adder = 4
    local ret

    if A > 2.5 then
        ret = x.slog
    else
        for i = 1, 30 do
            adder = adder / 2
            guesser = guesser + adder
            local sum_slog = mag_add(y, Qnum.fromSuperLogarithm(guesser))
            if sum_slog > x.slog then
                guesser = guesser - adder
            end
        end

        if guesser == -1 then
            guesser = guesser + adder
        end

        ret = guesser
    end

    return ret
end

function Qnum.add(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge and y.slog == math.huge then
        if x.sign == y.sign then return x else return Qnum.new(0) end
    end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end

    if x.sign == y.sign then
        local slog_res = mag_add(x, y)
        return Qnum.fromSuperLogarithm(slog_res, x.sign)
    else
        local cmp = compare_mag(x, y)
        if cmp >= 0 then
            local slog_res = mag_sub(x, y)
            return Qnum.fromSuperLogarithm(slog_res, x.sign)
        else
            local slog_res = mag_sub(y, x)
            return Qnum.fromSuperLogarithm(slog_res, y.sign)
        end
    end
end

function Qnum.sub(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end

    local neg_y = Qnum.fromSuperLogarithm(y.slog, -y.sign)
    return Qnum.add(x, neg_y)
end

function Qnum.mul(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end
    local ret
    local re
    local result_sign = x.sign * y.sign

    if y.slog > x.slog then
        ret = Qnum.mul(y, x).slog
    elseif math.floor(x.slog) > 3.5 then
        ret = x.slog
    elseif y.slog > 0 then
        ret = mag_add(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(y.slog - 1))
        ret = ret + 1
    elseif x.slog > 0 then
        re = math.log(1 / (1 + y.slog), 10)

        if re > 1 then
            re = 1 + math.log(re, 10)
        end

        if re > 2 then
            re = 2 + math.log(re - 1, 10)
        end

        ret = mag_sub(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(re - 1))
        ret = ret + 1

        if re - 1 > x.slog - 1 then
            ret = mag_sub(Qnum.fromSuperLogarithm(re - 1), Qnum.fromSuperLogarithm(x.slog - 1))
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

    return Qnum.fromSuperLogarithm(ret, result_sign)
end

function Qnum.div(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end
    local ret
    local re
    local result_sign = x.sign * y.sign

    if math.floor(x.slog) > 3.5 then
        ret = x.slog
    elseif y.slog > 0 then
        ret = mag_sub(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(y.slog - 1))
        ret = ret + 1
        if y.slog > x.slog then
            ret = mag_sub(Qnum.fromSuperLogarithm(y.slog - 1), Qnum.fromSuperLogarithm(x.slog - 1))
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

        ret = mag_add(Qnum.fromSuperLogarithm(x.slog - 1), Qnum.fromSuperLogarithm(re - 1))
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

    return Qnum.fromSuperLogarithm(ret, result_sign)
end

function Qnum.pow(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end

    local result_sign = 1
    if x.sign == -1 then
        local is_integer = false
        local is_odd = false
        local success, y_num = pcall(function() return y:ToNumber() end)
        if success and y_num then
            if y_num % 1 == 0 then
                is_integer = true
                if y_num % 2 ~= 0 then
                    is_odd = true
                end
            end
        else
            is_integer = true
            is_odd = false
        end

        if is_integer then
            result_sign = is_odd and -1 or 1
        else
            error("Domain error: negative base with non-integer exponent")
        end
    end

    local x_mag = Qnum.fromSuperLogarithm(x.slog, 1)
    local y_mag = Qnum.fromSuperLogarithm(y.slog, 1)

    local ret = Qnum.mul(Qnum.fromSuperLogarithm(x_mag.slog - 1), y_mag)
    ret.slog = ret.slog + 1
    ret.sign = result_sign

    if y.sign == -1 then
        ret = Qnum.div(Qnum.new(1), ret)
    end

    return ret
end

function Qnum.tetr(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
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

    return Qnum.fromSuperLogarithm(ret, x.sign)
end

function Qnum.exp(x)
    return Qnum.pow(Qnum.new(math.exp(1)), x)
end

function Qnum.__unm(x)
    if type(x) == "number" then x = Qnum.new(x) end
    return Qnum.fromSuperLogarithm(x.slog, -x.sign)
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

local function compare(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then y = 0 end
    if type(y) == "number" then y = Qnum.new(y) end

    if x.slog == -math.huge and y.slog == -math.huge then return 0 end

    if x.sign ~= y.sign then
        return x.sign > y.sign and 1 or -1
    end

    if x.slog == y.slog then return 0 end

    if x.sign == 1 then
        return x.slog > y.slog and 1 or -1
    else
        return x.slog < y.slog and 1 or -1
    end
end

function Qnum.__eq(x, y)
    return compare(x, y) == 0
end

function Qnum.__lt(x, y)
    return compare(x, y) < 0
end

function Qnum.__le(x, y)
    return compare(x, y) <= 0
end

function Qnum.cmp(x, y)
    local res = compare(x, y)
    if res > 0 then
        return ">"
    elseif res < 0 then
        return "<"
    else
        return "=="
    end
end

function Qnum.min(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end
    if compare(x, y) <= 0 then return x else return y end
end

function Qnum.max(x, y)
    if type(x) == "number" then x = Qnum.new(x) end
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end
    if compare(x, y) >= 0 then return x else return y end
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
    if y == nil then return x end
    if type(y) == "number" then y = Qnum.new(y) end
    if x.slog == math.huge then return x end
    if y.slog == math.huge then return y end
    return x ^ (1 / y)
end

function Qnum.abs(x)
    if type(x) == "number" then x = Qnum.new(x) end
    if x.slog == math.huge then return Qnum.fromSuperLogarithm(math.abs(x.slog), 1) end
    return Qnum.fromSuperLogarithm(x.slog, 1)
end

function Qnum:ToNumber()
    if self.slog > Qnum.new(1e308).slog then
        error("Unsupported number: number is too large")
    else
        local val = tonumber(self:ToString())
        assert(val, "Failed to convert Qnum to standard number")
        return val
    end
end

Qnum.pi = Qnum.new(math.pi)
Qnum.e = Qnum.new(math.exp(1))
Qnum._VERSION = "Qnum 1.10"

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

return Protect(Qnum)
