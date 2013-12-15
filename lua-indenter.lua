-- @Started: December 07, 2013, 08:37:25
-- @Author nkmathew <kipkoechmathew@gmail.com>

--[===[
### Lire Moi
==============
This is a not so primitive Lua indenter that to do as much 'beautification' 
as possible. It's different from most indenters out there in that instead of
simply iterating through every line and matching keywords, it walks the whole 
file character by character meaning it can do things like:
+ Detect string and comment regions that shouldn't be indented.
+ It makes it possible to align brackets and indent literal functions in a 
  floating manner like this:
    hypotenuse = function(base, height)
                   return math.sqrt(base * base + height * height)
                 end
+ It also makes it possible to space operators without affecting strings like
 when you use regular expressions

### Usage 
===============
indent.lua <filename> [[--no-basic] [--indent-comments] [--no-compact] [--align-brackets]]

--indent-comments, -ic  ## Causes comments to be indented like a normal line.
                           It's false by default in order to preseve any deliberate comment layout.

--no-compact, -nc       ## Removes extra whitespace and adds whitespace between operators.

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

### How it works
================
It iterates through every character in the string/file and when a keyword like 'if' or
'function' is found, it's position is pushed to a list and later popped back when an end
of block keyword like 'end' and 'until' is found. That popped position is used to restore 
the 'end' or 'until' keyword to the same level as the 'function' or 'if' keyword giving it
the floating effect. If basic mode is specified, the MO is the same only that instead of 
storing the position of the keyword, the current level is added to the indentation level 
and pushed to the list.

### Shortcomings
It doesn't handle 'CR' endings very well, io.lines is probably to blame.
It always writes with 'LF' endings.

]===]

function string:charAt(index)
  return string.sub(self, index, index)
end

function IsIncreaser(token)
  return token == "if" or token == "function" or
         token == "while" or token == "repeat" or token == "do" or
         token == "for"
end


function IsDecreaser(token)
  return token == "end" or token == "until"
end

function debug(...)
  print(string.format(...))
end

function debugList()
  for i, v in ipairs(positionList) do
    debug("--%s-- [1]: %s, [2]: %s, Line: %s", i, v[1], v[2], v.line)
  end
end



-------------------------------------------------------------------------------
-- Takes a string, an index and the characters adjacent to the character at that
-- index and decides whether the character should be appended to the passed string 
-- or not.
-- currChar and nextChar refer to the original string
-- prevChar, prevPrevChar and prevPrevPrevChar refer to the trimmed string.
-- This function is called for every iteration of the string.
-------------------------------------------------------------------------------
function AppendChar(str, prevChar, currChar, nextChar, prevPrevChar, i, prevPrevPrevChar)
  local trimmedStr = str
  -- NOTE: The statements below don't actually add space after a character. Adding 
  -- a space after a plus sign(+) for example is done by testing if the previous character 
  -- is plus sign(+) and appending a space before appending the current character.
  if not prevChar:find("[\t ]") and i ~= 1 and not currChar:find("[%])[:]") then
    if currChar:find("[%^>%<-/~+*]") and not currChar:find("[ \t]")
      and not prevChar:find("[({%[=,]") -- Don't add space after opening bracket
      then
      -- Add a space before operators(+, -, *, /) and the operands
      if not (currChar == "-" and prevChar == "-") then
        -- The test prevents it from splitting the two dash signs
        -- that indicate a comment
        trimmedStr = trimmedStr .. " "
      end
    elseif currChar == "=" and not prevChar:find("[=>%<~]") then
      -- Add a space before == and = without splitting ==
      trimmedStr = trimmedStr .. " "
    elseif currChar == "." and not prevChar:find("[.)(,]") and nextChar == "." then
      -- Add a space before ..
      trimmedStr = trimmedStr .. " "
    end
  end
  if not currChar:find("[\t ]") and not currChar:find("[%]) ]") then
    -- If the next character after the operator is not a space add
    -- one. If the current character is a square bracket, don't add a
    -- space because it is part of a long string or comment
    if prevChar:find("[-/+*^,)%%]")
      and not (prevPrevChar:find("[(]") and prevChar:find("[+-]")) -- Don't split sth like print(-3)
      and not (prevPrevPrevChar:find("[,]") and prevChar:find("[+-]")) -- Don't split print(-3, -3)
      and not (prevPrevPrevChar:find("[=]") and prevChar:find("[+-]")) -- Don't split sign in var = -3
      and not (currChar == "-" and prevChar == "-") -- Don't split comment markers
      and not (prevChar == "-" and currChar == "[") -- Don't put a space btw square bracket and comment marker
      and not (prevChar == ")" and currChar:find("[.:,%[+-*/=^]")) -- Don't split sth like ("This"):find("i")
      then
      -- Add a space after operators(+, -, *, /) and the operands
      trimmedStr = trimmedStr .. " "
    elseif prevPrevChar:find("[~>%<=]") and prevChar == "=" and currChar ~= " " then
      -- Add a space after <=, =>, ~=, ==
      trimmedStr = trimmedStr .. " "
    elseif currChar ~= "=" and prevChar:find("[>%<]") then
      -- Add a space after <, > without affecting <=, =>
      trimmedStr = trimmedStr .. " "
    elseif prevChar == "=" and not prevPrevChar:find("[>%<=~]") and currChar ~= "=" then
      -- Add a space after = without splitting ==
      trimmedStr = trimmedStr .. " "
    elseif currChar ~= "." and prevChar == "." and prevPrevChar == "." then
      -- Add a space after ..
      trimmedStr = trimmedStr .. " "
    end
  end
  ------------------------------------------------------------------------------------
  if not (prevChar:find("[ \t]") and currChar:find("[ \t]")) and
           not (i == 1 and currChar:find("[\t ]")) -- Make sure the first space is removed
    and not (prevChar:find("[({%[]") and currChar:find("[\t ]")) -- don't copy space after bracket
    and not (nextChar:find("[})%],]") and currChar:find("[\t ]")) -- don't copy space before closing bracket
    then
    -- Trimming happens here. We only copy the character if the previous character is
    -- not a space or a tab or a zero length string that way it strips all whitespace before
    -- the string. The last part of the test expression makes sure all trailing spaces are removed by not
    -- copying the first whitespace
    trimmedStr = trimmedStr .. currChar
  end
  return trimmedStr
end

escaped = false
inLongString = false
-- A long string can only be closed with the same number of equal signs.
inSingleQuotedString = false
inDoubleQuotedString = false
-- I'm being lazy here. These two variables should actually be in the loop because 
-- quoted strings cannot extend to the next lines without the backslash at the end.
-- By placing the variables here, I won't have to test for the backslash at the end 
-- of the string. This means that if you don't close your strings, the rest of the file
-- won't be indented the way you wanted.

currIndent = 0
equalSigns = 0 -- counting the equal signs between square brackets in long strings/comments
indentedCode = ""
-- `lastToken` is used to implement extra level
lastToken = ""
lineNumber = 0
nextIndent = 0
positionList = {}
indentedFile = assert(io.open("indented-file.lua", "wb"))
-- `indented-file` is an intermediate file that'll be later renamed to the filename passed.
-- The alternative way(overwriting) the file is not possible because the file will be in use
-- during the looping.

ALIGN_BRACKETS = false
BASIC_INDENTATION = true
INDENT_LEVEL = 2
COMPACT = true
-- In case the line ends with an 'or' or 'and' or '=', the next line is indented by EXTRA_LEVEL more
-- spaces so that return values don't align with the 'return' keyword.
EXTRA_LEVEL = 7
INDENT_COMMENTS = false

for i, v in ipairs(arg) do
  if v == "--no-basic" or v == "-nb" then
    BASIC_INDENTATION = false
  elseif v == "--indent-comments" or v == "-ic" then
    INDENT_COMMENTS = true
  elseif v == "--no-compact" or v == "-nc" then
    COMPACT = false
  elseif v == "--align-brackets" or v == "-ab"then
    ALIGN_BRACKETS = true
  end
end

foundLogicalOperator = false --used to implement EXTRA_LEVEL
rawFile = assert(io.open(arg[1], "r")) -- The filename must be the first argument
token = ""
for str in rawFile:lines() do
  inLineComment = false
  lineNumber = lineNumber + 1
  trimmedStr = ""
  currIndent = nextIndent
  skipCurrentCharacter = false
  -- add extra level if the line ends with 'and' or 'or'. Another variable is needed so that
  -- when set to true on this line, it'll affect the next line.
  addExtraLevel = foundLogicalOperator
  -- startsWithString prevents the indentation of a string in the case where the
  -- string ends on the current line. Having this variable saves us the trouble
  -- of moving the indentation part from the end to here and re-adjusting the
  -- variables.
  startsWithString = inSingleQuotedString or inDoubleQuotedString or inLongString
  if not startsWithString and not str:find("^[ \t]*-%-") then
    -- strip leading whitespace only if this line is not in a string or starts with a comment
    str = string.gsub(str, "^[\t ]*", "")
  end
  for i = 1, string.len(str) do
    currChar = str:charAt(i)
    local nextChar = str:charAt(i + 1)
    -- Since indexing starts from 1, getting the previous characater this
    -- way is safe.
    local prevChar = str:charAt(i - 1)
    local prevPrevChar = ""
    if i ~= 1 then
      -- This if condition is necessary in case the index is 1 which would
      -- give us the last character of the string.
      prevPrevChar = str:charAt(i - 2)
    end
    if escaped then
      escaped = false
      -- If Lua had a continue statement, it would have been here so that we skip this
      -- character. Another variable is used to achieve this.
      --debug("--escaped character at (%d, %d)", lineNumber, i)
      skipCurrentCharacter = true
    end
    if currChar == "\\" and not inLongString and not skipCurrentCharacter then
      escaped = true
      --debug("--escaped character at (%d, %d)", lineNumber, i)
    end

    if (str:find("^[ \t]*-%-[^[]", i) or str:find("^#")) and not
      (inSingleQuotedString or inDoubleQuotedString or inLongString) then
      -- If it finds a line comment, it should preserve the comment and all the
      -- space before it. It assumes that long comments start this way "--["
      -- debug("found line comment at '%s': (%d, %d)", currChar, lineNumber, i)
      inLineComment = true
      --debug("Found line comment at (%d, %d)", lineNumber, i)
      if str:find("^[ \t]*-%-") then
        if INDENT_COMMENTS then
          --print(string.format('--"%s", "%s" %d curr="%s"', str,  str:gsub("^[\t ]*", ""), lineNumber, currChar))
          str = str:gsub("^[ \t]*", "")
          currChar = "-" -- gsubbing the string above causes loss of one "-". this line restores it 
          startsWithString = false
        else
          startsWithString = true
        end
      end
    end
    if inSingleQuotedString or inDoubleQuotedString or inLongString or inLineComment then
      -- Append the characters the way they come so that the string/comment does not change
      --print(string.format("'%s'", trimmedStr))
      trimmedStr = trimmedStr .. currChar
      foundLogicalOperator = false
      --print("-->in string", lineNumber, i, inLineComment, inSingleQuotedString, currChar)
    else
      foundLogicalOperator = str:find("[ )]and *$") or str:find("[ )]or *$") or str:find("= *$")
      if COMPACT then
        prevPrevPrevChar = ""
        prevPrevPrevChar = trimmedStr:charAt(-3)
        p1 = trimmedStr:charAt(-1)
        p2 = trimmedStr:charAt(-2)
        trimmedStr = AppendChar(trimmedStr, p1, currChar, nextChar, p2, i, prevPrevPrevChar)
      else
        trimmedStr = trimmedStr .. currChar
      end
      ---------------------------------------------------------------
      --debugList(positionList)
      if currChar:find("[({]") then
        trimmedLength = string.len(trimmedStr)
        --debug("--curr-indent before bracket: %d %d", currIndent, nextIndent)
        if ALIGN_BRACKETS then
          table.insert(positionList, {currIndent + trimmedLength, trimmedLength, line = lineNumber})
        else
          nextIndent = nextIndent + INDENT_LEVEL
          table.insert(positionList, {nextIndent, INDENT_LEVEL, line = lineNumber})
        end
        --debug("+++++bracket '%s' at (%d, %d)", currChar, lineNumber, i)
        --debug("--curr-indent at bracket: %d %d", currIndent, nextIndent)
        --debug("--list at bracket: %s", table.concat(positionList[#positionList], " "))
      elseif currChar:find("[)}]") then
        pos = table.remove(positionList)
        if #positionList > 0 then
          --debug("--before subtracting bracket %d", nextIndent)
          nextIndent = nextIndent - pos[2]
          --debug("--after subtracting bracket %d", nextIndent)
          if not ALIGN_BRACKETS then
            if str:find("^[\t ]*[})]") then
              -- Makes sure that the closing bracket aligns with the head keyword like so:
              currIndent = currIndent - INDENT_LEVEL
            end
          end
        else
          -- If the list is empty, the next line will have zero indentation
          nextIndent = 0
          if not ALIGN_BRACKETS then
            if str:find("^[\t ]*[})]") then
              -- Makes sure that the closing bracket aligns with the head keyword like so:
              currIndent = currIndent - INDENT_LEVEL
            end
          end
        end
        --print("+++++found closing bracket at: ", nextIndent, currIndent, trimmedLength)
      end
      ---------------------------------------------------------------
      previousToken = token
      if (prevChar:find("[ \t>%<=+-*/^({,]") or prevChar == "") and currChar:find("[eiuwfdr]") then
        -- Test the characters that keywords start with instead of
        -- assuming that there'll always be a space before a keyword.
        substr = string.gsub(string.sub(str, i), "^[\t ]*", "") -- Slice to the end and strip leading whitespace
        _, nextSpace = string.find(substr, "[%(}) \t\n,{;\r]") -- Find the first space. The asterisk caters for a no match case
        token = string.sub(substr, 1, nextSpace) -- Get the token / keyword / function name
        token = string.gsub(token, "[%(}) \t\n,{;\r]", "")
        --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        -- Indentation level is determined here.
        if IsIncreaser(token) and token ~= "" then
          if not ((previousToken == "for" or previousToken == "while") and token == "do") then
            -- 'do' and 'for' are both increasers and since they can both be used together, you have
            -- to decide which keyword's position you are going to cache. This if loop makes sure that
            -- if a 'for' statement comes before a 'do', the 'do' keyword will be ignored.
            --debug("--curr-indent at increaser: %s", currIndent)
            if BASIC_INDENTATION then
              nextIndent = nextIndent + INDENT_LEVEL
              table.insert(positionList, {nextIndent, 0, line = lineNumber})
              --debug("--increaser: '%s' next-indent: %s", token, nextIndent)
            else
              indent = currIndent + (string.len(trimmedStr) - 1) + INDENT_LEVEL
              -- the second value in the list is used to calculate the position of 'end' or
              -- 'until' so that it aligns with the head keyword.
              table.insert(positionList, {indent, string.len(trimmedStr) - 1, line = lineNumber})
            end
            --print(string.format("-- prev: '%s' curr: '%s'", previousToken, token))
          end
        elseif token == "elseif" or token == "else" then
          pos = positionList[#positionList]
          if pos.line ~= lineNumber then
            --print("--", pos.line)
            currIndent = currIndent - INDENT_LEVEL
          end
        elseif IsDecreaser(token) and token ~= "" then
          --debug("--decreaser: '%s' line: %d", token, lineNumber)
          pos = table.remove(positionList)
          assert(pos, string.format("Excess 'end' statements: (%d, %d)", lineNumber, i))
          if pos.line ~= lineNumber then
            -- print("+++Next indent: ", pos[2], token, lineNumber)
            currIndent = pos[1] - INDENT_LEVEL
          end
          nextIndent = nextIndent - pos[2] - INDENT_LEVEL
        else
          token = previousToken
        end
        --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      end
    end
    if not skipCurrentCharacter and not inLineComment then
    -- The string detecting part has to be last in the block so that
    -- space can be added between equal signs and string quotes.
    ----------------------------------------------------------------------------
      if currChar:find("'") and not inDoubleQuotedString and not inLongString then
        -- Found the start of a single quoted string
        --debug("--Single quote at (%d, %d)", lineNumber, i)
        if inSingleQuotedString then
          inSingleQuotedString = false
        else
          inSingleQuotedString = true
        end
      end
    ----------------------------------------------------------------------------
      if currChar:find('"') and not (inSingleQuotedString or inLongString) then
        -- Found the start of a double quoted string.
        if inDoubleQuotedString then
          inDoubleQuotedString = false
        else
          inDoubleQuotedString = true
        end
      end
    -----------------------------LONG STRING DETERMINATION--------------------------------
    --------------------------------------------------------------------------------------
      if currChar == "[" and not (inLongString or inSingleQuotedString or inDoubleQuotedString) then
        -- We include inLongString in the condition because nesting of long strings is not
        -- possible. It'll simply be ignored.
        -- NOTE: inLongString includes both long/multiline comments since they pretty much look
        -- the same the difference being the two dashes.
        s, e = string.find(str, "^=*%[", i + 1)
        if s then
          equalSigns = e - s -- number of equal signs found
          inLongString = true
        end
      elseif currChar == "]" and inLongString then
        -- Possibly the end of a long string. Find the number of equal signs before this point
        -- and compare with the equal signs found earlier when the opening round bracket was
        -- found
        substr = string.sub(str, 1, i)
        s, e = string.find(substr, "%]=*%]$")
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
    elseif skipCurrentCharacter then
        --debug("-- skipping character '%s' (%d, %d) %s %s", currChar, lineNumber, i, skipCurrentCharacter, escaped)
      skipCurrentCharacter = false
    end
  end

  if startsWithString or str:find("^[ \t]*$") then
      -- Don't indent the line if it starts with a string
    indentedFile:write(trimmedStr .. "\n")
    print(trimmedStr)
  else
    if #positionList > 0 then
          --debug("Before assigning: %d", nextIndent)
      nextIndent = positionList[#positionList][1]
          --debug("after assigning: %d", nextIndent)
          --print("Next indent: ", nextIndent, lineNumber)
    end
    if addExtraLevel then
      indentedLine = string.rep(" ", currIndent + EXTRA_LEVEL) .. trimmedStr
      print(indentedLine)
          --nextIndent = nextIndent - EXTRA_LEVEL
      indentedFile:write(indentedLine .. "\n")
    else
      indentedLine = string.rep(" ", currIndent) .. trimmedStr
      print(indentedLine)
      indentedFile:write(indentedLine .. "\n")
    end
  end

  --debug("++Curr-level: %d, Next-level: %d, LINE: %d", currIndent, nextIndent, lineNumber)
  --print(table.concat(positionList, " "))
end

rawFile:close()
indentedFile:close()
assert(os.remove(arg[1]))
assert(os.rename("indented-file.lua", arg[1]))

