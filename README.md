"what next?" - simple command-line task-interdependency tracker

To run wn, you need [Lua](http://lua.org). That's it.

wn reads a file defining tasks and builds a dependency graph. Tasks are
scored by what depends on them, and how much completing them will
contribute to getting their dependants unstuck. Think of it as "make"
for your to-do list.

wn checks (in order) for a file called ".wn" in the current directory,
then the $WN_FILE environment variable, then "~/.wn". The file should be
structured like so:

    shoes Put on shoes
        DEP socks
        DEP find-shoes
    socks Put on socks

Any line beginning with a valid taskname (alphanumeric chars, _, ., or
-) and optional description defines a new task. Any line beginning with
whitespace and "DEP" marks it as depending on the other task (and
creates it, if necessary). For more syntactic details, see
examples/lebowski (*spoiler alert*).

Usage:

 * add - Add a new task (with optional description)
 * dep - Add new dependencies to a task (`wn.lua dep task dep1 dep2 ...`)
 * done - Flag a task as done (`wn.lua done taskname`)
 * graph - Generate .dot of dependency graph for Graphviz
 * help - Print this info
 * info - Print info about a task (`wn.lua info taskname`)
 * leaves - Print all leaves, sorted alphabetically
 * next - (default) Print next actionable tasks, sorted by score
 * tasks - Print all incomplete tasks, sorted alphabetically

To build a nice dependency graph, use e.g. `wn.lua graph | neato -Tpng > foo.png` . (which requires [Graphviz](http://graphviz.org/))

Coming soon:

 * adding dependencies to existing tasks via dep
 * simple Emacs wrapper
