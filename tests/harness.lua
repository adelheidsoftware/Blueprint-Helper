-- Blueprint Helper tests: the smallest possible assertion harness, shared by every *_test.lua.
-- Standalone Lua 5.4, no client. Each test file requires this module, calls `section` and the checks, and
-- run_all.lua prints the summary.

local Harness = {
    passed = 0,
    failed = 0,
    failures = {},
    current = "",
    PLUGIN_ROOT = nil, -- the plugin folder, set by run_all.lua
}

-- The levels by name, as the plugin numbers them.
Harness.LEVEL = { PERFECT = 0, EXCELLENT = 1, VERY_GOOD = 2, GOOD = 3, SATISFACTORY = 4, POOR = 5 }

function Harness.section(name)
    Harness.current = name
end

local function record(ok, message)
    if ok then
        Harness.passed = Harness.passed + 1
    else
        Harness.failed = Harness.failed + 1
        Harness.failures[#Harness.failures + 1] = Harness.current .. ": " .. message
    end
    return ok
end

function Harness.check(condition, message)
    return record(condition and true or false, message or "check failed")
end

function Harness.equal(actual, expected, message)
    return record(actual == expected,
        string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)))
end

function Harness.near(actual, expected, tolerance, message)
    return record(math.abs(actual - expected) <= tolerance,
        string.format("%s (expected %s ± %s, got %s)", message or "values differ", tostring(expected),
            tostring(tolerance), tostring(actual)))
end

-- Compares two arrays element by element.
function Harness.sameList(actual, expected, message)
    local same = #actual == #expected
    if same then
        for i = 1, #expected do
            if actual[i] ~= expected[i] then
                same = false
                break
            end
        end
    end
    return record(same, string.format("%s (expected {%s}, got {%s})", message or "lists differ",
        table.concat(expected, ","), table.concat(actual, ",")))
end

function Harness.summary()
    print(string.format("%d passed, %d failed", Harness.passed, Harness.failed))
    for _, failure in ipairs(Harness.failures) do
        print("  FAIL " .. failure)
    end
    return Harness.failed == 0
end

return Harness
