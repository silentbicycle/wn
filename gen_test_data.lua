local random = math.random

function randstr()
   local b = {}
   for i=1,random(25) do
      b[i] = string.char(96 + random(26))
   end
   return table.concat(b)
end


function gen_data(task_ct)
   task_ct = task_ct or 1000
   local tasks, seen = {}, {}
   local deps = {}
   for i=1,task_ct do
      local name = randstr()
      while seen[name] do name = randstr() end
      tasks[i] = name
      seen[name] = true
   end
   for i=1,task_ct do
      local ds = {}
      local max = random(50) - 20
      if max > 20 then for d=1,max do
            local id = random(task_ct)
            if id ~= i then ds[d] = id end
         end
      end
      deps[tasks[i]] = ds
   end

   for i=1,task_ct do
      local b = { tasks[i] .. " " .. randstr() }
      local ds = deps[tasks[i]]
      for _,d in ipairs(ds) do
         b[#b+1] = "    DEP " .. tasks[d]
      end
      b[#b+1] = ""
      print(table.concat(b, "\n"))
   end   
end

gen_data(100)
