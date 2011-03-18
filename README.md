"what next?" - simple command-line task-interdependency tracker

To run wn, you need [Lua](http://lua.org). That's it.

wn reads a file defining tasks and builds a dependency graph. Tasks are
scored by what depends on them, and how much completing them will
contribute to getting their dependants unstuck. Think of it as "make"
for your to-do list.

wn checks (in order) for a file called ".wn" in the current directory,
then the $WN_FILE environment variable, then "~/.wn". The file should be
structured like so:

    shoes socks find-shoes
    @desc shoes Put on shoes
    socks

The first token on a line is a task name, any following are dependencies
for that task. Task names can contain alphanumeric chars and [_.-]. Any

The line can also begin with some special commands, all of which begin with @:

    @desc taskname Add a description for a task
    @done taskname `(mark tags as complete)`
    @cost `(change task cost, defaults to 10)`
    @value `(change task value, defaults to 10)`

Lines that begin with anything else (or are empty) are ignored as comments.

For a larger example, see examples/lebowski (*spoiler alert*).

Command line options:

 * -v / --verbose: Print actions taken while reading input file
 * -h / --help:    Print commands
 * -f/ --file:     Use the filename given as the wn file

 * add:    Add a new task (with optional description), creating wn file if not present
 * dep:    Add new dependencies to a task (`wn.lua dep task dep1 dep2 ...`)
 * done:   Flag a task as done (`wn.lua done taskname`)
 * graph:  Generate .dot of dependency graph for Graphviz
 * help:   Print this info
 * info:   Print info about a task (`wn.lua info taskname`)
 * leaves: Print all leaves, sorted alphabetically
 * next:   (default) Print next actionable tasks, sorted by score
 * tasks:  Print all incomplete tasks, sorted alphabetically

To build a nice dependency graph, use e.g. `wn.lua graph | neato -Tpng > foo.png` . (which requires [Graphviz](http://graphviz.org/))

Coming soon:

 * adding dependencies to existing tasks via dep
 * simple Emacs wrapper
