local function oneless (a, ...) return ... end
local function f (n, a, ...)
  local b
  if n == 0 then
    local b, c, d = ...
    return a, b, c, d, oneless(oneless(oneless(...)))
  else
    n, b, a = n-1, ..., a
    print("n",n,"a",a,"b",b)
    return f(n, a, ...)
  end
end
local a,b,c,d,e = f(3,5,4,3,2,1)
print(a,b,c,d,e)
