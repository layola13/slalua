-- table.move semantics
local function eq(a, b, msg)
  if a ~= b then
    print("FAIL", msg, a, b)
  else
    print("ok", msg)
  end
end

-- basic move within the same table, backwards
local a = { 1, 2, 3, 4, 5 }
local r = table.move(a, 2, 4, 1)
eq(r, a, "returns destination table")
eq(#a, 5, "length preserved")
eq(a[1], 2, "move f->t")
eq(a[2], 3, "move f->t")
eq(a[3], 4, "move f->t")
eq(a[4], 4, "move f->t")
eq(a[5], 5, "move f->t")

-- forward move
local b = { 1, 2, 3, 4, 5 }
table.move(b, 1, 3, 3)
eq(b[1], 1, "forward src")
eq(b[2], 2, "forward src")
eq(b[3], 1, "forward dst")
eq(b[4], 2, "forward dst")
eq(b[5], 3, "forward dst")

-- copy to another table
local c = { 1, 2, 3 }
local d = {}
local dst = table.move(c, 1, 3, 1, d)
eq(dst, d, "returns second table")
eq(d[1], 1, "copy 1")
eq(d[2], 2, "copy 2")
eq(d[3], 3, "copy 3")

-- empty range is a no-op
local e = { 1, 2, 3 }
table.move(e, 2, 1, 1)
eq(#e, 3, "empty range keeps length")
eq(e[1], 1, "empty range keeps value")

-- gaps are preserved as nil holes
local f = { 1, 2, 3 }
f[2] = nil
local g = {}
table.move(f, 1, 3, 1, g)
eq(g[1], 1, "hole copy 1")
eq(g[2], nil, "hole copy 2")
eq(g[3], 3, "hole copy 3")

-- error cases
local ok, err = pcall(table.move, 1, 1, 1, 1)
eq(ok, false, "non table source errors")
eq(err, "bad argument #1 to 'move' (table expected)", "source error message")

ok, err = pcall(table.move, {}, 1, 1, 1, 1)
eq(ok, false, "non table destination errors")
eq(err, "bad argument #5 to 'move' (table expected)", "destination error message")

ok, err = pcall(table.move, {}, "x", 1, 1)
eq(ok, false, "non number f errors")
eq(err, "bad argument #2 to 'move' (number expected, got string)", "f error message")

ok, err = pcall(table.move, {}, 1, "x", 1)
eq(ok, false, "non number e errors")
eq(err, "bad argument #3 to 'move' (number expected, got string)", "e error message")

ok, err = pcall(table.move, {}, 1, 1, "x")
eq(ok, false, "non number t errors")
eq(err, "bad argument #4 to 'move' (number expected, got string)", "t error message")

ok, err = pcall(table.move, {}, 1, 1)
eq(ok, false, "missing t errors")
eq(err, "bad argument #4 to 'move' (number expected, got no value)", "missing t error message")

print("done")
