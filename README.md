### Lua Indenter

Lua code formatter written in Lua, then translated to C++

### Usage

    lua-indenter.lua <filename> [[--no-basic] [--indent-comments] [--no-compact] [--align-brackets]]

    --indent-comments, -ic  ## Causes line comments(not long comments) to be indented like every other line.
                               It's false by default in order to preseve any deliberate comment layout.

    --no-compact, -nc       ## Instructs the program to indent without messing with the
                               program layout like aligned equal signs or aligned tables(like the `network`
                               table below)

    --align-brackets, -ab   ## Aligns brackets like this:
                                network = {{name = "grauna",  IP = "210.26.30.34"},
                                           {name = "arraial", IP = "210.26.30.23"},
                                           {name = "lua",     IP = "210.26.23.12"},
                                           {name = "derain",  IP = "210.26.23.20"},
                                           }
                                when ALIGN_BRACKETS is false, brackets will cause an
                                increase in the indentation level by INDENT_LEVEL spaces.

    --no-basic, -nb        ## Strives to align the head keyword with the terminating
                                keyword no matter where it is in the line
                              It's default status is false. Using this option will give
                              you an indentation like the hypotenuse function mentioned earlier.

    --no-output, -no      ## Suppress outputting of the indented code.

    --no-extra-level, -ne ## Don't add EXTRA_LEVEL spaces to the indent level if
                             the line ends with 'and', 'or' or '='. It can make
                             some lines like these ones below clearer:

                                  return token == "end" or
                                         token == "until"
                            and at the same time more confusing when the placement
                            of the logical operators is not consistent.

                                  retval = first_val or
                                           second_val
                                  or third_val

                            The indentation will improve if the 'or' is placed at
                            the end of the second line:

                                  retval = first_val or
                                         second_val or
                                         third_val

    --reduce-space, -rs  ## Reduce all extraneous inter-word space to one space.
                            Setting this will destroy any aligned variables:
                            e.g
                            This code:
                                first_var  = 12
                                second     = 45
                                last       = "Last"
                            will be formatted to:
                                first_var = 12
                                second = 45
                                last ="Last"


    --spaces=<num>       ## Controls the indentation size

    --tabsize=<num>      ## Use tabs instead of spaces. You might get a mixture
                            of tabs and spaces when you use the **-nb** option
                            expecially when the words don't start on tabstops.

**TIP**: To get total alignment use both the **-nb** and **-ab** option. par example:

        describe('communicating with clients',
                 function()
                   local s
                   local on_new_echo_client
                   before(function()
                            s = server.copas.listen
                            {port = port,
                             protocols = {echo = function(client)
                                                   on_new_echo_client(client)
                                                 end
                                          }
                             }
                          end)
                 end)
            -- The drawback of this is that it can take up too much screen real estate.
    The above code would look like this with the default options:

        describe('communicating with clients',
          function()
            local s
            local on_new_echo_client
            before(function()
                s = server.copas.listen
                {port = port,
                  protocols = {echo = function(client)
                      on_new_echo_client(client)
                    end
                  }
                }
              end)
          end)

### Shortcomings

+ It doesn't handle adjacent long comments/string markers very well. It uses a
  simple  pattern to match the square brackets and won't know that the comment has
  not been closed  in something like `--[[[  ]]`.

+ It also doesn't process line continuation characters in strings. It assumes
  that single-quoted and double-quoted strings behave like long strings, i.e can
  extend to subsequent lines. This shouldn't be too big a problem. You'll get the
  correct indentation if you close your strings and ensure your code is
  syntactically correct.

+ It won't space an expression like this `result = DN2E+25` properly because
  it can only look back at most three characters(`prevPrevPrevChar`). Fixing
  this would require another variable to be passed(`prevPrevPrevPrevChar`).
  It looks like a bit too much...
