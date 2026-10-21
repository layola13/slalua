print("hello", 1 + 2, 3 * 4)
local function add(a, b) return a + b end
print(add(5, 7))
local t = { 10, 20, 30 }
print(t[1], t[2], t[3])
local s = 0
for i = 1, 5 do s = s + i end
print("sum", s)
if s > 10 then print("big") else print("small") end
