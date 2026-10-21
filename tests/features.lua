local t = { a = 1, b = 2, [3] = "x" }
print(t.a, t.b, t[3])
t.a = 10
print(t.a)
local i = 0
while i < 3 do i = i + 1 end
print("while", i)
repeat i = i - 1 until i == 0
print("repeat", i)
local s = ""
for k, v in pairs(t) do s = s .. tostring(k) .. "=" .. tostring(v) .. ";" end
print(s)
local function var(...) return select("#", ...), ... end
print(var(1, 2, 3))
local function counter()
  local n = 0
  return function() n = n + 1; return n end
end
local c = counter()
print(c(), c(), c())
print(string.sub("abcdef", 2, 4), string.upper("hi"), string.rep("ab", 2))
print(table.concat({1,2,3}, "-"))
local tt = {10,20}
table.insert(tt, 30)
table.insert(tt, 1, 5)
print(table.remove(tt), table.concat(tt, ","))
print(math.floor(3.7), math.ceil(3.2), math.abs(-4), math.max(1, 9, 3))
print(pcall(function() error("boom") end))
local ok, err = pcall(function() return 1 + nil end)
print(ok, err)
goto skip
print("not printed")
::skip::
print("after goto")
