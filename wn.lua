#!/usr/bin/env lua

--[[
Copyright (c) 2010 Scott Vokes <vokes.s@gmail.com>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.
 
THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
--]]

local fmt = string.format       --just a common abbrev


-------------
-- Reading --
-------------

-- If given a filename, open that, else $WN_FILE, else ~/.wn.
local function open_file(fn)
   local ok, f
   if fn then return assert(io.open(fn, 'r')) end
   ok, f = pcall(io.open, ".wn", "r")
   if ok and f then return f end
   fn = os.getenv("WN_FILE") or os.getenv("HOME") .. "/.wn"
   return assert(io.open(fn, 'r'))
end

local function add(dat, task)
   if task and task.name then
      if dat[task.name] then error("Item already exists: " .. task.name) end
      dat[task.name] = task
   end
end

local function newtask(name, descr) return { name=name, descr=descr or "", deps={} } end

-- Read the graph from the wn file.
-- Each line is either "taskname [description]", "DONE taskname",
-- or "    CMD arg" where CMD is DEP (add-dependency), COST, or PRIORITY.
local function read(str)
   local dat, done, cur = {}, {}, nil
   local line_ct = 1
   local dep_only = {}          --tasks that only exist as dependencies

   local function fail(msg)
      msg = msg or fmt("Error in line %d: %s", line_ct, tostring(line))
      error(msg)
   end

   for line in str:gmatch("([^\n]+)") do
      local ws, first, rest = line:match("^(%s*)(%a[%w_.-]*)%s*(.*)")
      if ws then
         if ws:len() == 0 then
            if first:len() > 0 then        --begins w/ a new task or DONE
               if first == "DONE" then 
                  local name = line:match("^DONE%s+([%a_.-]*)")
                  if name then done[name] = true else fail() end
               else
                  if cur then add(dat, cur) end
                  cur = newtask(first, rest)
                  dep_only[first] = nil    --mark as created already
               end
            end
         else
            if first == "DEP" then
               local name = line:match("DEP%s+([%a_.-]*)")
               if cur and name then
                  cur.deps[#cur.deps+1] = name
                  if not dat[name] then dep_only[name] = true end
               else
                  fail()
               end
            elseif first == "COST" then
               local cost = line:match("COST%s+(%d+)")
               if cur and cost then cur.cost = tonumber(cost) else fail() end
            elseif first == "PRIORITY" or first == "PRIO" then
               local prio = line:match("PRIO[A-Z]*%s+(%d+)")
               if cur and prio then cur.priority = tonumber(prio) else fail() end
            else
               fail()
            end
         end
      else
         fail()
      end
      line_ct = line_ct + 1
   end

   -- Create any tasks which are only deps to others
   for name in pairs(dep_only) do add(dat, newtask(name)) end

   if cur then add(dat, cur) end

   for key in pairs(done) do
      local item = dat[key]
      if item then item.done = true end
   end
   return dat
end


----------
-- Data --
----------

local function get_descr(task, width)
   return task.descr or " "
end

local function get_priority(task)
   return task.priority or 10
end

local function get_cost(task)
   return task.cost or 10
end

local function get_cost_of_deps(task)
   local t = 0
   for _,dep in ipairs(task.deps) do t = t + get_cost(dep) end
   return t
end

-- Format a task list for printing.
local function get_task_list(ts, columns, scores)
   local b, maxlen, max = {}, 1, math.max
   for id,val in ipairs(ts) do
      maxlen = max(maxlen, val.name:len())
   end

   local name_fmt = "%-" .. tostring(maxlen) .. "s   "

   for id,val in ipairs(ts) do
      local name = name_fmt:format(val.name)
      local descr = (val.descr or ""):sub(1, columns - maxlen - 3)
      b[#b+1] = (name .. descr):gsub(" *$", "")
   end
   return table.concat(b, "\n")
end


--------------
-- Commands --
--------------

local function cmd_next(cfg, dat)
   -- Figure out all leaves, and weight according to score.
   -- The score of a leaf is the sum of (dependee priority * (cost
   -- the leaf represents / total cost of all its deps)) - cost.
   local ls, ds = {}, {}      --leaves, dependants
   for key,task in pairs(dat) do
      if not next(task.deps) and not task.done then
         ls[#ls+1] = task
      else
         for _,d in ipairs(task.deps) do
            local dlist = ds[d] or {}
            dlist[#dlist+1] = task
            ds[d] = dlist
         end
      end
   end

   local ss = {}
   local function get_score(leaf, depth)
      local s = ss[leaf]
      if s then return s end
      depth = depth or 10
      if depth == 0 then return get_priority(leaf) end
      local t, lcost = get_priority(leaf), get_cost(leaf)
      for _,task in ipairs(ds[leaf.name] or {}) do
         t = t + get_score(task, depth-1) * (lcost / get_cost_of_deps(task))
      end
      ss[leaf.name] = t
      return t
   end

   for _,leaf in ipairs(ls) do ss[leaf.name] = get_score(leaf) end

   table.sort(ls, function(a,b) return ss[a.name] > ss[b.name] end)   --by score
   local columns = tonumber(os.getenv("COLUMNS") or 72)
   print(get_task_list(ls, columns, ss))
end

local function cmd_leaves(cfg, dat)
   local ls = {}
   for key,task in pairs(dat) do
      if task.deps and not next(task.deps) then ls[#ls+1] = task end
   end

   table.sort(ls, function(a,b) return a.name < b.name end)
   local columns = tonumber(os.getenv("COLUMNS") or 72)
   print(get_task_list(ls, columns))
end

local function cmd_tasks(cfg, dat)
   local ts = {}
   for _,task in pairs(dat) do ts[#ts+1] = task end

   table.sort(ts, function(a,b) return a.name < b.name end)
   local columns = tonumber(os.getenv("COLUMNS") or 72)
   print(get_task_list(ts, columns))
end

local function append(cfg, str)
   local f = assert(io.open(cfg.file, 'a'))
   assert(f:write(str))
   assert(f:close())
end

local function cmd_done(cfg, dat, name)
   assert(name, "Task name required")
   append(cfg, fmt("DONE %s\n", name))
end

local function cmd_add(cfg, dat, name, ...)
   assert(name, "Task name required")
   if dat[name] then error(fmt("Task %q already exists", name)) end
   local descr = table.concat({...}, " ")
   append(cfg, fmt("%s %s\n", name, descr))
end

local function cmd_dep(cfg, dat, name, ...)
   assert(name, "Task name required")
   local deps = { ... }
   assert(#deps > 0, "Dependency names required")
   if not dat[name] then
      local b = { name }
      for _,dep in ipairs(deps) do b[#b+1] = "    DEP " .. dep end
      append(cfg, table.concat(b, "\n"))
   else
      error "TODO - add dep to existing task"
   end
end

local function cmd_info(cfg, dat, key)
   assert(key, "Task key required")
   local task = dat[key]
   if not task then error("Not found: " .. key) end
   print(fmt("%s %s\n    PRIORITY %d\n    COST %d",
             task.name, get_descr(task), get_priority(task), get_cost(task)))
   for _,key in pairs(task.deps) do
      print("    DEP " .. key)
   end
end

local function cmd_graph(cfg, dat)
   local b = {'strict digraph{'}
   b[#b+1] = '    overlap="false";'
   for key,node in pairs(dat) do
      local ckey = key:gsub("-", "_")
      if not node.done then
         local leaf = #node.deps == 0 and ' style="filled" peripheries=2' or ""
         local label = ckey --.. " " .. tostring(node.cost or 10)
         b[#b+1] = fmt("    %s[label=%q%s];", ckey, label, leaf)
         for i,dep in ipairs(node.deps) do
            b[#b+1] = fmt("    %s->%s;", ckey, dep:gsub("-", "_"))
         end
      end
   end
   b[#b+1] = "}"
   local dot = table.concat(b, "\n")
   print(dot)
end

local cmds

local function cmd_help(cfg, dat)
   print "Usage:"
   local b = {}
   for name,info in pairs(cmds) do
      b[#b+1] = fmt("  %-6s - %s", name, info[2])
   end
   table.sort(b)
   print(table.concat(b, "\n"))
end

cmds = {
   done={ cmd_done, 'Flag a task as done ("wn.lua done taskname")' },
   graph={ cmd_graph, "Generate .dot of dependency graph for Graphviz" },
   help={ cmd_help, "Print this info"},
   info={ cmd_info, 'Print info about a task ("wn.lua info taskname")' },
   leaves={ cmd_leaves, "Print all leaves, sorted alphabetically" },
   next={ cmd_next, "(default) Print next actionable tasks, sorted by score" },
   tasks={ cmd_tasks, "Print all incomplete tasks, sorted alphabetically" },
   add={ cmd_add, "Add a new task (with optional description)",
         vararg=true },
   dep={ cmd_dep, 'Add new dependencies to a task ("wn.lua dep task dep1 dep2 ...")',
         vararg=true },
}


------------------
-- Command line --
------------------

local function parse_opts(arg)
   local cfg = {}
   local i, len = 1, #arg
   local function drop(ct)
      for idx=1,ct do table.remove(arg, i) end
      i = i - (ct-1)
   end

   while i <= len do
      local cur = arg[i]
      if not cur then break end
      if cur == "-f" or cur == "--file" then cfg.file = arg[i+1]
         drop(2)
      elseif cur == "-h" or cur == "--help" then
         cmd_help()
         os.exit(0)
      elseif cmds[cur] then
         local info = cmds[cur]
         cfg.cmd = info
         drop(1)
      elseif not cfg.cmd or not cfg.cmd.vararg then
         error("Unrecognized option: " .. tostring(cur))
      end
      i = i + 1
   end

   cfg.cmd = (cfg.cmd and cfg.cmd[1]) or cmd_next
   arg[-1] = nil; arg[0] = nil
   cfg.cmd_args = arg
   return cfg
end

local function main(arg)
   cfg = parse_opts(arg)
   local f = open_file(cfg.file)
   local dat = read(f:read("*a"))
   if cfg.cmd then cfg.cmd(cfg, dat, unpack(cfg.cmd_args or {})) end
end

if arg then main(arg) end
