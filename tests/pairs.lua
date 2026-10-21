local t = { a = 1, b = 2 }
print("t.a", t.a)
print("pt", pairs(t))
local it, st, ctl = pairs(t)
print("it", it, st, ctl)
local k, v = it(st, ctl)
print("next", k, v)
print("done")
