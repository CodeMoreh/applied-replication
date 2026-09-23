-- core-runs.lua – lifts optional runs into a deck's main flow.
--
-- Every slide of an optional run carries `.deepdive` and a `run` attribute
-- (tools, r, methods, multiverse) in slides/_segments/. A deck lists the runs
-- it carries in its main flow under `core-runs:` in its YAML; this filter
-- removes the .deepdive class from those headings, so nav-tools.html neither
-- hides them on the d toggle nor badges them as optional. Two filter tables,
-- because pandoc walks the body before Meta unless Meta is given first.
local core = {}

local function read_meta(m)
  if m["core-runs"] then
    for _, v in ipairs(m["core-runs"]) do
      core[pandoc.utils.stringify(v)] = true
    end
  end
end

local function lift(h)
  local run = h.attributes["run"]
  if run and core[run] and h.classes:includes("deepdive") then
    h.classes = h.classes:filter(function(c) return c ~= "deepdive" end)
  end
  return h
end

return {
  { Meta = read_meta },
  { Header = lift },
}
