#!/usr/bin/lua5.2
help = [===[  

## lua-indenter.lua
**Started:** December 07, 2013, 08:37:25  
**Date:** December 15, 2013  
**Author:** nkmathew <kipkoechmathew@gmail.com>  
**Home:** [http://gist.github.com/nkmathew/7969358](http://gist.github.com/nkmathew/7969358)  
**Cloning:** https://gist.github.com/7969358.git  

This is a not so primitive Lua indenter that tries to do as much 'beautification'  
as possible. It's different from most indenters out there in that instead of  
simply iterating through every line and matching keywords, it walks the whole  
file character by character; meaning it can do things like:  

+ Detect string and comment regions that shouldn't be indented.  
+ Align head and terminating keywords anywhere on the line:  

                hypotenuse = function(base, height)  
                               return math.sqrt(base * base + height * height)  
                             end  

+ Insert spaces between operators without affecting strings or comments, something  
  that can be quite hard with regular expressions(at least with Lua's)  
  
###Usage  

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
      
  
###How it works  

It iterates through every character in the string/file and when a keyword like *if* or  
*function* is found, it's position is pushed to a list and later popped back when an end  
of block keyword like *end* and *until* is found. That popped position is used to restore  
the *end* or *until* keyword to the same level as the *function* or *if* keyword.  
If **--basic** option is used, the MO is the same only that instead of storing the  
position of the keyword, the current level is added to the indentation level and  
pushed to the list.  

###Revision History

+ 18th December 2013  
    - Can now handle files with CR line endings.  
    - Does not insert an extra line at the end of the file.  
    - Preserves the file's line ending
    - Does not split the negative sign and the number in calculations.

+ 23rd December 2013  
    - All CR characters are replaced with LF before being printed to the console  
      so that all the content can be seen.  

+ 25th December 2013  
    - Fix for failed detection of the end of a long comment/string caused by a  
      wrong regex pattern.  
    - Prevent a space from being added at the end of the line if the line ends  
      with an operator. It causes unnecessary generation of a diff file.  

+ 30th December 2013  
    - Can now handle for/while constructs that have the 'do' keyword in a different line.  
      Like when you use an 'literal' iterator in the 'for' header.
      
              -- a contrived example(from the PiL book)
              lst = {"GitHub", "BitBucket", "Git", "Subversion"}  
              for vcs in (function (tbl)  
                    local index = 0  
                    return function () index = index + 1; return tbl[index] end
                  end) (lst) do
                print(vcs)
              end

+ 2nd January 2014
    - Issues warning when excess or unmatched brackets are encountered.  
 

###Shortcomings  

+ It doesn't indent with tabs.  

+ It doesn't handle adjacent long comments/string markers very well. It uses a  
  simple  pattern to match the square brackets and won't know that the comment has  
  not been closed  in something like `--[[[  ]]`.  

+ It also doesn't process line continuation characters in strings. It assumes  
  that single-quoted and double-quoted strings behave like long strings, i.e can  
  extend to subsequent lines. This should't be too big a problem. You'll get the  
  correct indentation if you close your strings and ensure your code is  
  syntactically correct.  

]===]

function string:charAt(index)
  return string.sub(self, index, index)
end

function IsIncreaser(token)
  -- An alternative to this function would be to use a table with the keywords
  -- as keys and their values as true
  return token == "if" or token == "function" or
         token == "while" or token == "repeat" or token == "do" or
         token == "for"
end

function IsDecreaser(token)
  return token == "end" or token == "until"
end

-- Splits the text into an array of separate lines.
function split(text, sep)
  sep = sep or "\n"
  local lines = {}
  local pos = 1
  while true do
    local b, e = text:find(sep, pos)
    if not b then
      --  If the string doesn't end with the separator, add the rest to the table
      --  and exit
      table.insert(lines, text:sub(pos))
      break
    end
    table.insert(lines, text:sub(pos, b - 1))
    pos = e + 1
  end
  return lines
end


function mapConcatenate(tbl, char)
  -- Maps the character to every string in the table.
  local table = tbl
  for i, v in ipairs(table) do
    table[i] = table[i] .. char
  end
  return table
end


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Takes a string, an index and the characters adjacent to the character at that
-- index and decides whether the character should be appended to the passed
-- string or not.
-- currChar and nextChar refer to the original string
-- prevChar, prevPrevChar and prevPrevPrevChar refer to the trimmed string.
-- This function is called for every iteration of the string.
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function AppendChar(str, prevChar, currChar, nextChar, prevPrevChar, i, prevPrevPrevChar)
  local trimmedLine = str
  -- This functions contains hacks that enable the program to space operators
  -- correctly.  I had to experiment a little before getting them right.
  -- NOTE: The statements below don't actually add space after a character.
  -- Adding a space after a plus sign(+) for example is done by testing if the
  -- previous character is plus sign(+) and appending a space before appending
  -- the current character.
  if not prevChar:find("[\t ]") -- No need to add a space if there's already one
    and i ~= 1 -- Don't add a space if the operator is the first character
    and not currChar:find("[%])[:\n\r]") -- Don't add space if at the end of the line
    then
    if currChar:find("[%^>%<-/~+*]")
      and not prevChar:find("[({%[=,]") -- Don't add space after opening bracket
      then
      -- Add a space before operators(+, -, *, /) and the operands
      if not (currChar == "-" and prevChar == "-") then
        -- The test prevents it from splitting the two dash signs
        -- that indicate a comment
        trimmedLine = trimmedLine .. " "
      end
    elseif currChar == "=" and not prevChar:find("[=>%<~]") then
      -- Add a space before == and = without splitting ==
      trimmedLine = trimmedLine .. " "
    elseif currChar == "." and not prevChar:find("[.){}(,]") and nextChar == "." then
      -- Add a space before ..
      trimmedLine = trimmedLine .. " "
    end
  end
  if not currChar:find("[%])} \r\n\t]") then
    -- If the next character after the operator is not a space add
    -- one. If the current character is a square bracket, don't add a
    -- space because it is part of a long string or comment
    if prevChar:find("[-/+*^,)%%]")
      and not (prevPrevChar:find("[(=/*]") and prevChar:find("[+-]")) -- Don't split sth like print(-3)
      and not (prevPrevPrevChar:find("[,]") and prevChar:find("[+-]")) -- Don't split print(-3, -3)
      and not (prevPrevPrevChar:find("[=*^/]") and prevChar:find("[+-]")) -- Don't split sign in var = -3
      and not (currChar == "-" and prevChar:find("[-*/^]")) -- Don't split comment markers
      and not (prevChar == "-" and currChar == "[") -- Don't put a space btw square bracket and long comment marker
      and not (prevChar == ")" and currChar:find("[:,%[+-*/=^]")) -- Don't split sth like ("This"):find("i")
      and not (prevChar == ")" and currChar == "." and nextChar ~= ".") -- split sth like (func()).."\n"
      then
      -- Add a space after operators(+, -, *, /) and the operands
      trimmedLine = trimmedLine .. " "
    elseif prevPrevChar:find("[~>%<=]") and prevChar == "=" and currChar ~= " " then
      -- Add a space after <=, =>, ~=, ==
      trimmedLine = trimmedLine .. " "
    elseif currChar ~= "=" and prevChar:find("[>%<]") then
      -- Add a space after <, > without affecting <=, =>
      trimmedLine = trimmedLine .. " "
    elseif prevChar == "=" and not prevPrevChar:find("[>%<=~]") and currChar ~= "=" then
      -- Add a space after = without splitting ==
      trimmedLine = trimmedLine .. " "
    elseif currChar ~= "." and prevChar == "." and prevPrevChar == "." then
      -- Add a space after ..
      trimmedLine = trimmedLine .. " "
    end
  end
  --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if not (prevChar:find("[ \t]") and currChar:find("[ \t]")) and
           not (prevChar == "" and currChar:find("[\t ]")) -- Make sure the first space is removed
    and not (prevChar:find("[({%[]") and currChar:find("[\t ]")) -- don't copy space after bracket
    and not (nextChar:find("[})%],]") and currChar:find("[\t ]")) -- don't copy space before closing bracket
    then
    -- Trimming happens here. We only copy the character if the previous
    -- character is not a space or a tab or a zero length string that way it
    -- strips all whitespace before the string. The last part of the test
    -- expression makes sure all trailing spaces are removed by not copying the
    -- first whitespace
    trimmedLine = trimmedLine .. currChar
  end
  return trimmedLine
end

escaped = false
inLongString = false
-- A long string can only be closed with the same number of equal signs.
inSingleQuotedString = false
inDoubleQuotedString = false
-- I'm being lazy here. These two variables should actually be in the loop
-- because quoted strings cannot extend to the next lines without the backslash
-- at the end.  By placing the variables here, I won't have to test for the
-- backslash at the end of the string. This means that if you don't close your
-- strings, the rest of the file won't be indented the way you wanted.

currIndent = 0
equalSigns = -999 -- equal signs between square brackets in long strings/comments
indentedCode = ""
lineNumber = 0
nextIndent = 0
positionList = {} -- Store the indentation level

ALIGN_BRACKETS = false
BASIC_INDENTATION = true
INDENT_LEVEL = 2
COMPACT = true
-- In case the line ends with an 'or' or 'and' or '=', the next line is indented
-- by EXTRA_LEVEL more spaces so that return values don't align with the
-- 'return' keyword.
EXTRA_LEVEL = 7
INDENT_COMMENTS = false
OUTPUT = true
-- Process commandline arguments
for _, v in ipairs(arg) do
  if v == "--no-basic" or v == "-nb" then
    BASIC_INDENTATION = false
  elseif v == "--indent-comments" or v == "-ic" then
    INDENT_COMMENTS = true
  elseif v == "--no-compact" or v == "-nc" then
    COMPACT = false
  elseif v == "--align-brackets" or v == "-ab" then
    ALIGN_BRACKETS = true
  elseif v == "--no-output" or v == "-no" then
    OUTPUT = false
  elseif v == "--no-extra-level" or v == "-ne" then
    NO_EXTRA_LEVEL = true
  end
end

if NO_EXTRA_LEVEL then
  EXTRA_LEVEL = 0
end

foundLogicalOperator = false --used to implement EXTRA_LEVEL
-- The filename must be the first argument
if #arg == 0 then
  -- No commandline arguments passed. Print usage instructions and exit
  print(help)
  os.exit(0)
end
rawFile = assert(io.open(arg[1], "rb"), string.format("Invalid filename: `%s'", arg[1]))

CR = "\r"
LF = "\n"
CRLF = CR .. LF
lineEnding = ""

slurpedContents = rawFile:read("*all") -- Slurp file contents
rawFile:close()
-- Find file's line ending
if slurpedContents:find(CRLF) then
  lineEnding = CRLF
elseif slurpedContents:find(CR) then
  lineEnding = CR
else
  lineEnding = LF
end

indentedFile = assert(io.open("temp-file", "wb"))
-- `temp-file` is the intermediate file that will be renamed to the passed
-- filename and the original file deleted. The alternative(overwriting the file)
-- causes unpleasant results, like a chopped file when an assertion fails
-- because of the file writing process being interrupted.

-- Split the string into lines
codeLines = split(slurpedContents, lineEnding)

-- Restore the line endings without adding an extra line
if codeLines[#codeLines] == "" then
  codeLines[#codeLines] = nil
  codeLines = mapConcatenate(codeLines, lineEnding) -- Restore the line endings
else
  codeLines = mapConcatenate(codeLines, lineEnding)
  -- Restore the line endings
  codeLines[#codeLines] = (codeLines[#codeLines]):gsub(lineEnding, "")
end

token = ""
-- forKeyword and whileKeyword help in handling 'do' keywords that are in a
-- different line from that of the 'for' or 'while' keyword.
forKeyword = false
whileKeyword = false
bracketCount = 0
for _, line in ipairs(codeLines) do
  inLineComment = false
  lineNumber = lineNumber + 1
  trimmedLine = ""
  currIndent = nextIndent
  skipCurrentCharacter = false
  -- add extra level if the line ends with 'and' or 'or'. Another variable is
  -- needed so that when set to true on this line, it'll affect the next line.
  addExtraLevel = foundLogicalOperator
  -- startsWithString prevents the indentation of a string in the case where the
  -- string ends on the current line. Having this variable saves us the trouble
  -- of moving the indentation part from the end to here and re-adjusting the
  -- variables.
  startsWithString = inSingleQuotedString or inDoubleQuotedString or inLongString
  spacesRemoved = line:len()
  if not startsWithString and not ((not line:find("^[ \t]*-%-%[=*%[") and
               line:find("^[ \t]-%-")) and not INDENT_COMMENTS) then
    -- strip leading whitespace only if this line is not in a string or starts
    -- with a comment
    line = string.gsub(line, "^[\t ]*", "")
    spacesRemoved = spacesRemoved - line:len()
  end
  for i = 1, string.len(line) do
    currChar = line:charAt(i)
    local nextChar = line:charAt(i + 1)
    -- Since indexing starts from 1, getting the previous character this
    -- way is safe.
    local prevChar = line:charAt(i - 1)
    local prevPrevChar = ""
    if i ~= 1 then
      -- This if condition is necessary in case the index is 1 which would
      -- give us the last character of the string.
      prevPrevChar = line:charAt(i - 2)
    end
    if escaped then
      escaped = false
      -- If Lua had a continue statement, it would have been here so that we
      -- skip this character. Another variable is used to achieve this.
      skipCurrentCharacter = true
    end

    if currChar == "\\" and not inLongString and not skipCurrentCharacter then
      escaped = true
    end

    if (line:find("^[ \t]*-%-", i) and not line:find("^[ \t]*-%-%[=*%[", i)
        or line:find("^#!")) and not
      (inSingleQuotedString or inDoubleQuotedString or inLongString) then
      -- If it finds a line comment, it should preserve the comment and all the
      -- space before it. It also detects a shebang so that the forward slashes
      -- won't become spaced
      inLineComment = true
      if line:find("^[ \t]*-%-") then
        if INDENT_COMMENTS then
          startsWithString = false
        else
          startsWithString = true
        end
      end
    end

    if inSingleQuotedString or inDoubleQuotedString or inLongString or inLineComment then
      -- Append the characters the way they come so that the string/comment does
      -- not change
      trimmedLine = trimmedLine .. currChar
      foundLogicalOperator = false
    else
      foundLogicalOperator = line:find("[ )]and *[\r\n]") or
             line:find("[ )]or *[\r\n]") or line:find("= *[\r\n]")
      if COMPACT then
        prevPrevPrevChar = ""
        prevPrevPrevChar = trimmedLine:charAt(-3)
        char1 = trimmedLine:charAt(-1) -- Previous character in the trimmed line
        char2 = trimmedLine:charAt(-2) -- Previous previous character in the trimmed line
        trimmedLine = AppendChar(trimmedLine, char1, currChar, nextChar, char2, i, prevPrevPrevChar)
      else
        trimmedLine = trimmedLine .. currChar
      end
      --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      if currChar:find("[({]") then
        bracketCount = bracketCount + 1
        trimmedLength = string.len(trimmedLine)
        if ALIGN_BRACKETS then
          table.insert(positionList, {currIndent + trimmedLength,
              trimmedLength, line = lineNumber, token = currChar, offset = i})
        else
          nextIndent = nextIndent + INDENT_LEVEL
          table.insert(positionList, {nextIndent, INDENT_LEVEL, line = lineNumber,
              token = currChar, offset = i})
        end
      elseif currChar:find("[)}]") then
        assert(((#positionList > 0) and (bracketCount > 0)),
          string.format("Excess bracket `%s' around (%d, %d)",
            currChar, lineNumber, spacesRemoved + i))
        bracketCount = bracketCount - 1
        pos = table.remove(positionList)
        if pos.token == "(" then
          correctCloser = ")"
        elseif pos.token == "{" then
          correctCloser = "}"
        end
        assert(currChar == correctCloser,
          string.format("Bracket `%s' at (%d, %d) does not match `%s' at (%d, %d)",
            pos.token, pos.line, pos.offset, currChar, lineNumber, spacesRemoved + i))
        local substr = string.sub(line, 1, i + 1)
        if #positionList > 0 then
          if not ALIGN_BRACKETS then
            nextIndent = nextIndent - INDENT_LEVEL
            if i == 1 then
              --[[Makes sure that the closing bracket aligns with the head keyword like so:
                      return {
                         "Sherlock";
                         "Watson"
                      }
              ]]
              currIndent = currIndent - INDENT_LEVEL
            end
          end
        else
          -- If the list is empty, the next line will have zero indentation
          nextIndent = 0
          if not ALIGN_BRACKETS then
            if i == 1 then
              -- Makes sure that the closing bracket aligns with the head
              -- keyword as shown earlier.
              currIndent = currIndent - INDENT_LEVEL
            end
          end
        end
      end
      if (prevChar:find("[ \t>%<=+-*/^(){,\"';]") or prevChar == "") and currChar:find("[eiuwfdr]") then
        --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Extract token/keyword ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Test the characters that keywords start with instead of
        -- assuming that there'll always be a space before a keyword.
        substr = string.gsub(string.sub(line, i), "^[\t ]*", "") -- Slice to the end and strip leading whitespace
        _, nextSpace = string.find(substr, "[%(}) \t\n,\"'{;\r-]")
        token = string.sub(substr, 1, nextSpace) -- Get the token/keyword/function name
        token = string.gsub(token, "[%(}) \t\n'\",{;\r-]", "")
        --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Calculate the next line's indentation level ]~~~~~~~~~~~~~~~~~~
        -- Indentation level is determined here.
        if IsIncreaser(token) and token ~= "" then
          if token == "for" then
            forKeyword = true
          elseif token == "while" then
            whileKeyword = true
          end
          if not ((forKeyword or whileKeyword) and token == "do") then
            -- 'do' and 'for' are both increasers and since they can both be
            -- used together, you have to decide which keyword's position you
            -- are going to cache(esp with -nb option). This if loop makes sure
            -- that if a 'for' statement comes before a 'do', the 'do' keyword
            -- will be ignored.
            if BASIC_INDENTATION then
              nextIndent = nextIndent + INDENT_LEVEL
              table.insert(positionList, {nextIndent, 0, line = lineNumber, token = token, offset = i})
            else
              indent = currIndent + (string.len(trimmedLine) - 1) + INDENT_LEVEL
              -- the second value in the list is used to calculate the position
              -- of 'end' or 'until' so that it aligns with the head keyword.
              table.insert(positionList, {indent, string.len(trimmedLine) - 1, line = lineNumber,
                  token = token, offset = i})
            end
          end
          if token == "do" and forKeyword then
            forKeyword = false
          elseif token == "do" and whileKeyword then
            whileKeyword = false
          end
        elseif token == "elseif" or token == "else" then
          pos = positionList[#positionList]
          if pos.line ~= lineNumber then
            currIndent = currIndent - INDENT_LEVEL
          end
        elseif IsDecreaser(token) and token ~= "" then
          pos = table.remove(positionList)
          assert(pos, string.format("Unmatched `%s' statement at (%d, %d)", token, lineNumber, i))
          if pos.line ~= lineNumber then
            -- This test prevents an end statement from decreasing the current
            -- indentation level in the case of a one-line block. This wouldn't
            -- be necessary if we just matched the number of increasers minus
            -- the number of decreasers.
            currIndent = pos[1] - INDENT_LEVEL
          end
          if BASIC_INDENTATION then
            nextIndent = nextIndent - pos[2] - INDENT_LEVEL
          elseif pos.line ~= lineNumber then
            -- Decrease the indent level only if not in a one-liner
            nextIndent = nextIndent - INDENT_LEVEL
          end
        end
        --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      end
    end
    if not skipCurrentCharacter and not inLineComment then
      -- The string detecting part has to be last in the block so that
      -- space can be added between equal signs and string quotes.
      --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      if currChar:find("'") and not inDoubleQuotedString and not inLongString then
        -- Found the start of a single quoted string
        if inSingleQuotedString then
          inSingleQuotedString = false
        else
          inSingleQuotedString = true
        end
      end
      --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      if currChar:find('"') and not (inSingleQuotedString or inLongString) then
        -- Found the start of a double quoted string.
        if inDoubleQuotedString then
          inDoubleQuotedString = false
        else
          inDoubleQuotedString = true
        end
      end
      --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      if currChar == "[" and not (inLongString or inSingleQuotedString or inDoubleQuotedString) then
        -- We include inLongString in the condition because nesting of long
        -- strings is not possible. It'll simply be ignored.
        -- NOTE: inLongString includes both long/multiline comments since they
        -- pretty much look the same the difference being the two dashes.
        s, e = string.find(line, "^=*%[", i + 1)
        if s then
          equalSigns = e - s -- number of equal signs found
          inLongString = true
        end
      elseif currChar == "]" and inLongString then
        -- Possibly the end of a long string. Find the number of equal signs
        -- before this point and compare with the equal signs found earlier when
        -- the opening round bracket was found
        substr = string.sub(line, 1, i)
        s, e = string.find(substr, "%]=*%]")
        if s then
          n = e - s - 1 -- number of equal signs found
        else
          n = -999 -- assign dummy value because ]] has zero equal signs between the brackets.
        end
        if n == equalSigns then
          -- If the equal signs match those found earlier, it means the string/comment has been closed.
          inLongString = false
        end
      end
      --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    elseif skipCurrentCharacter then
      skipCurrentCharacter = false
    end
  end

  if startsWithString or line:find("^[ \t]*[\r\n]") then
    -- Don't indent the line if it starts with a string
    indentedFile:write(trimmedLine)
    -- The gsub below is a hack for SciTE and the console. CRLF characters tend
    -- to insert an extra line even with buffering switched off with
    -- io.stdout:setvbuf 'no' It also makes sure that files with CR line endings
    -- will have all their content printed.
    if OUTPUT then
      io.write((trimmedLine:gsub("\r\n?", '\n')))
    end
  else
    if #positionList > 0 then
      nextIndent = positionList[#positionList][1]
    else
      nextIndent = 0
    end
    if addExtraLevel then
      -- increase the indentation by EXTRA_LEVEL spaces if the line ends with
      -- 'and', 'or' or '='
      indentedLine = string.rep(" ", currIndent + EXTRA_LEVEL) .. trimmedLine
      if OUTPUT then
        io.write((indentedLine:gsub("\r\n?", '\n')))
      end
      indentedFile:write(indentedLine)
    else
      -- Otherwise indent using the current indentation
      indentedLine = string.rep(" ", currIndent) .. trimmedLine
      if OUTPUT then
        io.write((indentedLine:gsub("\r\n?", '\n')))
      end
      indentedFile:write(indentedLine)
    end
  end
end

indentedFile:close()
assert(os.remove(arg[1])) -- Deletes the original file
assert(os.rename("temp-file", arg[1]))

assert(not inLongString, "You have unterminated long strings/comments")
assert(not inSingleQuotedString, "You have an unterminated single quoted string")
assert(not inDoubleQuotedString, "You have an unterminated double quoted string")

assert(#positionList == 0, "You have unfinished blocks")

