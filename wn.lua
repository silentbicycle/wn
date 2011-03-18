#!/usr/bin/env lua

--[[
Copyright (c) 2010-11 Scott Vokes <vokes.s@gmail.com>

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


-- TODO: add @load [filename] and @wait TASKNAME datespec

local cmds                                  --forward reference


-------------
-- Reading --
-------------

local function exists(n)
   local ok, f=io.open(n)
   if ok and f then f:close() end
   return ok
end
 
-- If given a filename, open that, else check ./.wn, $WN_FILE, and ~/.wn (in that order).
local function open_file(cfg, mode)
   local fn = cfg.file
   local ok, f
   for _,path in ipairs{fn or "", ".wn", os.getenv("WN_FILE") or "",
                        os.getenv("HOME") .. "/.wn"} do
      if path ~= "" then
         if exists(path) then
            return assert(io.open(path, mode))
         elseif cfg.cmd == cmds.add[1] then
            local f, err = io.open(path, 'w')        --create it
            return f
         end
      end
   end
   print("No wn file found.")
   os.exit(1)
end

local function add(dat, task)
   if task and task.name then
      if dat[task.name] then return end
      dat[task.name] = task
   end
end

local function errmsg(msg) print(msg); os.exit(1) end
local function newtask(name, descr) return { name=name, descr=descr or "", deps={} } end

-- Read the graph from the wn file.
-- Each line is either "taskname deptask*" or "@CMD ARGS".
local function read(str, verbose)
   str = str or ""
   local dat, done = {}, {}
   local line_ct, line = 1
   local dep_only = {}          --tasks that only exist as dependencies

   local function fail(msg)
      errmsg(msg or fmt("Error in line %d: %s", line_ct, tostring(line)))
   end

   local function add(taskname)
      dat[taskname] = dat[taskname] or newtask(taskname)
      dep_only[taskname] = nil
      if verbose then print(fmt("-- added: %s", taskname)) end
   end

   local function add_dep(taskname, dep)
      local t = dat[taskname]
      t.deps[#t.deps+1] = dep
      if not dat[dep] then dep_only[dep] = true end
      if verbose then print(fmt("-- dependency, %s <- %s", taskname, dep)) end
   end

   local function add_descr(taskname, descr)
      local t = dat[taskname]
      if verbose then print(fmt("-- description for %s: %s", taskname, descr)) end
      if t then t.descr = descr else fail() end
   end

   local function set_scoring(taskname, category, value)
      local t = dat[taskname]
      if t then t[category] = value else fail() end
      if verbose then print(fmt("-- %s for %s to %d\n", category, task, value)) end
   end

   local function import_wnfile(fn)
      -- TODO
   end

   local function wait(taskname, timestamp)
      -- TODO
   end

   for l in str:gmatch("([^\n]+)") do
      line = l
      if line:match("^@") then              --begins w/ command
         local cmd, rest = line:match("^@(%a+) +(.*)$")
         if cmd then
            cmd = cmd:lower()               --@done @desc @cost @value @load
            if cmd == "done" then
               for task in rest:gmatch("([%w_.-]+)") do
                  if verbose then print(fmt("-- done: %s", task)) end
                  done[task] = true
               end
            elseif cmd == "desc" then
               local task, desc = rest:match("([%w_.-]+) (.*)")
               if task then add_descr(task, desc) else fail() end
            elseif cmd == "cost" then
               local task, cost = rest:match("([%w_.-]+) (%d+)")
               if task and cost then set_scoring(task, "cost", tonumber(cost)) else fail() end
            elseif cmd == "value" then
               local task, val = rest:match("([%w_.-]+) (%d+)")
               if task and val then set_scoring(task, "priority", tonumber(val)) else fail() end
            elseif cmd == "load" then
               -- TODO
               fail "TODO"
            elseif cmd == "wait" then
               -- TODO
               fail "TODO"
            else
               fail()
            end
         else
            fail()
         end
      elseif line:match("^%w") then       --begins w/ task
         local task = line:match("^([%w_.-]+)")
         local deplist = line:match("^[%w_.-]+ +(.*)$") or ""
         if task then
            local deps = {}
            for dep in deplist:gmatch("([%w_.-]+)") do deps[#deps+1]=dep end
            add(task)
            for _,d in ipairs(deps) do add_dep(task, d) end
         else
            fail()
         end
      else                                  --treat as comment

      end
      line_ct = line_ct + 1
   end

   -- Create any tasks which are only deps to others
   for name in pairs(dep_only) do add(name) end

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
   local scores = scores or {}
   local b, maxlen, max = {}, 1, math.max
   for id,val in ipairs(ts) do
      maxlen = max(maxlen, val.name:len())
   end

   local name_fmt = "%-" .. tostring(maxlen) .. "s   "

   for id,val in ipairs(ts) do
      local name = name_fmt:format(val.name)
      local score = scores[val.name] and fmt("%.2f ", scores[val.name]) or ""
      local descr = (val.descr or ""):sub(1, columns - maxlen - 3)
      b[#b+1] = fmt("%s%s%s", score, name, descr):gsub(" *$", "")
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
   local f = open_file(cfg, 'a')
   assert(f:write(str))
   assert(f:close())
end

local function cmd_done(cfg, dat, name)
   if not name then errmsg "Task name required" end
   append(cfg, fmt("@done %s\n", name))
end

local function cmd_add(cfg, dat, name, ...)
   if not name then errmsg "Task name required" end
   if dat[name] then errmsg(fmt("Task %q already exists.", name)) end
   local descr = table.concat({...}, " ")
   local buf = {}

   buf[1] = fmt("%s\n", name)
   if descr and descr ~= "" then buf[2] = fmt("@desc %s %s\n", name, descr) end
   append(cfg, table.concat(buf))
end

local function cmd_dep(cfg, dat, name, ...)
   if not name then errmsg "Task name required" end
   local deps = { ... }
   if #deps == 0 then errmsg "Dependency names required." end
   local b = { name }
   for _,dep in ipairs(deps) do b[#b+1] = " " .. dep end
   append(cfg, table.concat(b) .. "\n")
end

local function cmd_info(cfg, dat, key)
   if not key then errmsg "Task key required" end
   local task = dat[key]
   if not task then errmsg("Not found: " .. key) end
   print(fmt("%s - Priority: %d Cost: %d Descr: %s",
             task.name, get_priority(task), get_cost(task), get_descr(task)))
   for _,key in pairs(task.deps) do
      print("    Dep: " .. key)
   end
end

local function cmd_graph(cfg, dat)
   local b = {'strict digraph{'}
   b[#b+1] = '    overlap="false";'
   for key,node in pairs(dat) do
      local ckey = key:gsub("-", "_")
      local leaf = #node.deps == 0 and ' style="filled" peripheries=2' or ""
      if node.done then leaf = ' style="dotted" peripheries=1' end

      local label = ckey --.. " " .. tostring(node.cost or 10)
      b[#b+1] = fmt("    %s[label=%q%s];", ckey, label, leaf)
      for i,dep in ipairs(node.deps) do
         b[#b+1] = fmt("    %s->%s;", ckey, dep:gsub("-", "_"))
      end
   end
   b[#b+1] = "}"
   local dot = table.concat(b, "\n")
   print(dot)
end

local function cmd_help(cfg, dat)
   print "Usage: wn [-v|--verbose] [-f|--file wnfile] [-h|--help] [COMMAND ARGS]"
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
      elseif cur == "-v" or cur == "--verbose" then
         cfg.verbose = true
      elseif cmds[cur] then
         local info = cmds[cur]
         cfg.cmd = info
         drop(1)
      elseif not cfg.cmd or not cfg.cmd.vararg then
         errmsg("Unrecognized option: " .. tostring(cur))
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
   local f = assert(open_file(cfg, 'r'))
   local dat = read(f:read("*a"), cfg.verbose)
   if cfg.cmd then cfg.cmd(cfg, dat, unpack(cfg.cmd_args or {})) end
end

if arg then main(arg) end
