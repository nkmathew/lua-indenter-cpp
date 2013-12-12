-- Started: 07, 2013, 08:37:25

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
indent.lua <filename> [[--basic] [--indent-comments] [--compact] [--indent-brackets]]

--indent-comments ## By default comment lines are not indented in order to preserve any
                  ## deliberate layouts.
--compact ## Removes extra whitespace and adds whitespace between operators.
--indent-brackets ## Aligns brackets like this:
    network = {{name = "grauna",  IP = "210.26.30.34"},
               {name = "arraial", IP = "210.26.30.23"},
               {name = "lua",     IP = "210.26.23.12"},
               {name = "derain",  IP = "210.26.23.20"},
               }
--basic  ## The indentation is simply a matter of subtracting and adding to the current 
            level like most lua indenters.
        It is usefull when a program uses literal functions that might consume a lot of
        screen real estate.

### How it works
================
It iterates through every character in the string/file and when a keyword like 'if' or
'function' is found, it's position is pushed to a list and later popped back when an end
of block keyword like 'end' and 'until' is found. That popped position is used to restore 
the 'end' or 'until' keyword to the same level as the 'function' or 'if' keyword giving it
the floating effect. If basic mode is specified, the MO is the same only that instead of 
storing the position of the keyword, the current level is added to the indentation level 
and pushed to the list.
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

function AppendChar(str, prevChar, currChar, nextChar, prevPrevChar, i, prevPrevPrevChar)
  -- The function concatenates the current character to the passed string
  -- selectively so that in the end the whole string looks trimmed.
  -----------------------------------------------------------------------------------
  local trimmedStr = str
  -- NOTE: The statements below don't actually add space after a character. Adding 
  -- a space after a plus sign(+) for example is done by testing if the previous character 
  -- is plus sign(+) and appending a space before appending the current character.
  if not prevChar:find("[\t ]") and i ~= 1 and not currChar:find("[%])[.:]") then
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
    elseif currChar == "." and prevChar ~= "." and nextChar == "." then
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

bracketList = {}
currIndent = 0
equalSigns = 0
indentedCode = ""
lastToken = ""
lineNumber = 0
nextIndent = 0
positionList = {}
token = ""
indentedFile = assert(io.open("indented-file.lua", "w"))

INDENT_BRACKETS = false
BASIC_INDENTATION = false
INDENT_LEVEL = 2
COMPACT = true
-- In case the line ends with an 'or' or 'and' the next line is indented by EXTRA_LEVEL more
-- spaces so that return values don't align with the 'return' keyword.
EXTRA_LEVEL = 0
INDENT_COMMENTS = true
foundLogicalOperator = false
rawFile = assert(io.open(arg[1], "r"))
token = ""
for str in rawFile:lines() do
  inSingleQuotedString = false
  inDoubleQuotedString = false
  inLineComment = false
  lineNumber = lineNumber + 1
  trimmedStr = ""
  currIndent = nextIndent
  -- add extra level if the line ends with 'and' or 'or'. Another variable is needed so that
  -- when set to true on this line, it'll affect the next line.
  addExtraLevel = foundLogicalOperator
  -- startsWithString prevents the indentation of a string in the case where the string ends
  -- on the current line. Having this variable saves us the trouble of moving the indentation part from
  -- the end to here and re-adjusting the variables.
  startsWithString = inSingleQuotedString or inDoubleQuotedString or inLongString
  if not startsWithString and not str:find("^[ \t]*-%-") then
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
    if currChar == "\\" then
      escaped = true
    end

    if str:find("^[ \t]*-%-[^[]", i) and not (inSingleQuotedString or inDoubleQuotedString or inLongString) then
      -- If it finds a line comment, it should preserve the comment and all the
      -- space before it. It assumes that long comments start this way "--["
      inLineComment = true
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
      --print("-->in string", lineNumber, i, inLongString, inSingleQuotedString, currChar)
    else
      foundLogicalOperator = str:find("[ )]and *$") or str:find("[ )]or *$")
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
      if currChar:find("[({]") then
        table.insert(bracketList, (currIndent + i))
        trimmedLength = string.len(trimmedStr)
        if INDENT_BRACKETS then
          table.insert(positionList, {(currIndent + trimmedLength) , trimmedLength})
        else
          table.insert(positionList, {(currIndent + INDENT_LEVEL) , trimmedLength})
        end
        --print("+++++found opening bracket at: ", currIndent, trimmedLength)
      elseif currChar:find("[)}]") then
        table.remove(bracketList)
        pos = table.remove(positionList)
        if #positionList > 0 then
          nextIndent = nextIndent - pos[1]
          if not INDENT_BRACKETS then
            if str:find("^[\t ]*[})]") then
              currIndent = currIndent - INDENT_LEVEL
            end
          end
        else
          nextIndent = 0
          if not INDENT_BRACKETS then
            if str:find("^[\t ]*[})]") then
              currIndent = currIndent - INDENT_LEVEL
            end
          end
        end
        --print("+++++found closing bracket at: ", nextIndent, currIndent, trimmedLength)
      end
      ---------------------------------------------------------------
      previousToken = token
      if (prevChar:find("[ \t>%<=+-*/^(]") or prevChar == "") and currChar:find("[eiuwfdr]") then
        -- Test the characters that keywords start with instead of
        -- assuming that there'll always be a space before a keyword.
        substr = string.gsub(string.sub(str, i) , "^[\t ]*", "") -- Slice to the end and strip leading whitespace
        _, nextSpace = string.find(substr, "[ ({,]") -- Find the first space. The asterisk caters for a no match case
        token = string.sub(substr, 1, nextSpace) -- Get the token / keyword / function name
        token = string.gsub(token, "[%() \t\n,]", "")
        --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        -- Indentation level is determined here.
        if IsIncreaser(token) and token ~= "" then
          -- We add the current accumulated string length so that the some blocks like
          -- anonymous functions have their 'end' aligning with the 'function'
          --print("next indent: ", nextIndent, lineNumber, )
          -- We also need to store the string length at that time so that when it comes
          -- to restoring the level, we can just subtract from the current level.
          -- Substract 1 from the string length since indexing starts from 1
          if not ((previousToken == "for" or previousToken == "while") and token == "do") then
            if BASIC_INDENTATION then
              nextIndent = nextIndent + INDENT_LEVEL
              table.insert(positionList, {nextIndent, 0, line = lineNumber})
            else
              nextIndent = nextIndent + (string.len(trimmedStr) - 1) + INDENT_LEVEL
              table.insert(positionList, {nextIndent, string.len(trimmedStr) - 1, line = lineNumber})
            end
            --print("--", previousToken, token)
            --print(string.format("--increaser: '%s'", token))
          end
        elseif token == "elseif" or token == "else" then
          pos = positionList[#positionList]
          if pos.line ~= lineNumber then
            --print("--", pos.line)
            currIndent = currIndent - INDENT_LEVEL
          end
        elseif IsDecreaser(token) and token ~= "" then
          --print(string.format("--decreaser: '%s'", token))
          pos = table.remove(positionList)
          assert(pos, string.format("Excess 'end' statements: (%d, %d)", lineNumber, i))
          --if pos.line ~= lineNumber then
          nextIndent = nextIndent - pos[2] - INDENT_LEVEL
          -- print("+++Next indent: ", pos[2], token, lineNumber)
          currIndent = pos[1] - INDENT_LEVEL
          --end
        else
          token = previousToken
        end
        --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      end
    end
    if not escaped and not inLineComment then
      -- The string detecting part has to be last in the block so that
      -- space can be added between equal signs and string quotes.
      --escaped = false
      ----------------------------------------------------------------------------
      if currChar:find("'") and not inDoubleQuotedString and not inLongString then
        -- Found the start of a single quoted string
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
    else
      escaped = false
    end
  end

  if startsWithString or str:find("^[ \t]*$") then
    -- Don't indent the line if it starts with a string
    indentedFile:write(trimmedStr .. "\n")
    print(trimmedStr)
  else
    if #positionList > 0 then
      nextIndent = positionList[#positionList][1]
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

  --print("Next indent: ", nextIndent, lineNumber)
  --print(table.concat(positionList, " "))
end

rawFile:close()
indentedFile:close()
assert(os.remove(arg[1]))
assert(os.rename("indented-file.lua", arg[1]))

