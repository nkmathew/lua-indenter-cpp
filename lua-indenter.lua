
--[===[  

## lua-indenter.lua
**Started:** December 07, 2013, 08:37:25  
**Date:** December 15, 2013  
**Author:** nkmathew <kipkoechmathew@gmail.com>  
**Revision:** 17

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

###What it doesn't do  

+ Indent with tabs.  


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


-------------------------------------------------------------------------------
-- Takes a string, an index and the characters adjacent to the character at that
-- index and decides whether the character should be appended to the passed string 
-- or not.
-- currChar and nextChar refer to the original string
-- prevChar, prevPrevChar and prevPrevPrevChar refer to the trimmed string.
-- This function is called for every iteration of the string.
-------------------------------------------------------------------------------
function AppendChar(str, prevChar, currChar, nextChar, prevPrevChar, i, prevPrevPrevChar) 
  local trimmedLine = str
  -- This functions contains hacks that enable the program to space operators correctly. 
  -- I had to experiment a little before getting them right.
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
        trimmedLine = trimmedLine .. " "
      end
    elseif currChar == "=" and not prevChar:find("[=>%<~]") then
      -- Add a space before == and = without splitting ==
      trimmedLine = trimmedLine .. " "
    elseif currChar == "." and not prevChar:find("[.)(,]") and nextChar == "." then
      -- Add a space before ..
      trimmedLine = trimmedLine .. " "
    end
  end
  if not currChar:find("[\t ]") and not currChar:find("[%]) ]") then
    -- If the next character after the operator is not a space add
    -- one. If the current character is a square bracket, don't add a
    -- space because it is part of a long string or comment
    if prevChar:find("[-/+*^,)%%]") 
      and nextChar:find("[\r\n]") -- Don't add a space if at the end of the line
      and nextChar ~= "" -- Don't add a space if at the end of a string
      and not (prevPrevChar:find("[(=/*]") and prevChar:find("[+-]")) -- Don't split sth like print(-3)
      and not (prevPrevPrevChar:find("[,]") and prevChar:find("[+-]")) -- Don't split print(-3, -3)
      and not (prevPrevPrevChar:find("[=*^/]") and prevChar:find("[+-]")) -- Don't split sign in var = -3
      and not (currChar == "-" and prevChar:find("[-*/^]")) -- Don't split comment markers
      and not (prevChar == "-" and currChar == "[") -- Don't put a space btw square bracket and comment marker
      and not (prevChar == ")" and currChar:find("[.:,%[+-*/=^]")) -- Don't split sth like ("This"):find("i")
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
    trimmedLine = trimmedLine .. currChar
  end
  return trimmedLine
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

ALIGN_BRACKETS = false
BASIC_INDENTATION = true
INDENT_LEVEL = 2
COMPACT = true
-- In case the line ends with an 'or' or 'and' or '=', the next line is indented by EXTRA_LEVEL more
-- spaces so that return values don't align with the 'return' keyword.
EXTRA_LEVEL = 7
INDENT_COMMENTS = false

-- Process commandline arguments
for _, v in ipairs(arg) do
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
-- The filename must be the first argument
rawFile = assert(io.open(arg[1], "rb"), string.format("Invalid filename: `%s'", arg[1])) 

CR = "\r"
LF = "\n"
CRLF = CR .. LF
lineEnding = ""

slurpedContents = rawFile:read("*all") -- Slurp file contents
rawFile:close() 
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
-- causes unpleasant results, like a chopped file when an assertion fails because of the
-- file writing process being interrupted.

-- Split the string into lines
codeLines = split(slurpedContents, lineEnding) 

-- Restore the line endings without adding an extra line
if codeLines[#codeLines] == "" then
  codeLines[#codeLines] = nil
  codeLines = mapConcatenate(codeLines, lineEnding) -- Restore the line endings
else
  codeLines = mapConcatenate(codeLines, lineEnding) 
  codeLines[#codeLines] = (codeLines[#codeLines]):gsub(lineEnding, "") -- Restore the line endings
end

token = ""
for _, line in ipairs(codeLines) do
  inLineComment = false
  lineNumber = lineNumber + 1
  trimmedLine = ""
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
  if not startsWithString and not line:find("^[ \t]*-%-") then
    -- strip leading whitespace only if this line is not in a string or starts with a comment
    line = string.gsub(line, "^[\t ]*", "") 
  end
  for i = 1, string.len(line) do
    currChar = line:charAt(i) 
    local nextChar = line:charAt(i + 1) 
    -- Since indexing starts from 1, getting the previous characater this
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
      -- If Lua had a continue statement, it would have been here so that we skip this
      -- character. Another variable is used to achieve this.
      skipCurrentCharacter = true
    end

    if currChar == "\\" and not inLongString and not skipCurrentCharacter then
      escaped = true
    end

    if (line:find("^[ \t]*-%-[^[]", i) or line:find("^#")) and not
      (inSingleQuotedString or inDoubleQuotedString or inLongString) then
      -- If it finds a line comment, it should preserve the comment and all the
      -- space before it. It assumes that long comments start this way "--["
      inLineComment = true
      if line:find("^[ \t]*-%-") then
        if INDENT_COMMENTS then
          line = line:gsub("^[ \t]*", "") 
          currChar = "-" -- gsubbing the string above causes loss of one "-". this line restores it 
          startsWithString = false
        else
          startsWithString = true
        end
      end
    end

    if inSingleQuotedString or inDoubleQuotedString or inLongString or inLineComment then
      -- Append the characters the way they come so that the string/comment does not change
      trimmedLine = trimmedLine .. currChar
      foundLogicalOperator = false
    else
      foundLogicalOperator = line:find("[ )]and *[\r\n]$") or line:find("[ )]or *[\r\n]$") or line:find("= *[\r\n]$") 
      if COMPACT then
        prevPrevPrevChar = ""
        prevPrevPrevChar = trimmedLine:charAt(-3) 
        char1 = trimmedLine:charAt(-1) -- Previous character in the trimmed line
        char2 = trimmedLine:charAt(-2) -- Previous previous character in the trimmed line
        trimmedLine = AppendChar(trimmedLine, char1, currChar, nextChar, char2, i, prevPrevPrevChar) 
      else
        trimmedLine = trimmedLine .. currChar
      end
      ---------------------------------------------------------------
      if currChar:find("[({]") then
        trimmedLength = string.len(trimmedLine) 
        if ALIGN_BRACKETS then
          table.insert(positionList, {currIndent + trimmedLength, trimmedLength, line = lineNumber}) 
        else
          nextIndent = nextIndent + INDENT_LEVEL
          table.insert(positionList, {nextIndent, INDENT_LEVEL, line = lineNumber}) 
        end
      elseif currChar:find("[)}]") then
        pos = table.remove(positionList) 
        if #positionList > 0 then
          nextIndent = nextIndent - pos[2]
          if not ALIGN_BRACKETS then
            if line:find("^[\t ]*[})]") then
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
            if line:find("^[\t ]*[})]") then
              -- Makes sure that the closing bracket aligns with the head keyword as shown earlier.
              currIndent = currIndent - INDENT_LEVEL
            end
          end
        end
      end
      ---------------------------------------------------------------
      previousToken = token
      if (prevChar:find("[ \t>%<=+-*/^({,]") or prevChar == "") and currChar:find("[eiuwfdr]") then
        -- Test the characters that keywords start with instead of
        -- assuming that there'll always be a space before a keyword.
        substr = string.gsub(string.sub(line, i), "^[\t ]*", "") -- Slice to the end and strip leading whitespace
        _, nextSpace = string.find(substr, "[%(}) \t\n,{;\r-]")
        token = string.sub(substr, 1, nextSpace) -- Get the token / keyword / function name
        token = string.gsub(token, "[%(}) \t\n,{;\r-]", "") 
        --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        -- Indentation level is determined here.
        if IsIncreaser(token) and token ~= "" then
          if not ((previousToken == "for" or previousToken == "while") and token == "do") then
            -- 'do' and 'for' are both increasers and since they can both be used together, you have
            -- to decide which keyword's position you are going to cache. This if loop makes sure that
            -- if a 'for' statement comes before a 'do', the 'do' keyword will be ignored.
            if BASIC_INDENTATION then
              nextIndent = nextIndent + INDENT_LEVEL
              table.insert(positionList, {nextIndent, 0, line = lineNumber}) 
            else
              indent = currIndent + (string.len(trimmedLine) - 1) + INDENT_LEVEL
              -- the second value in the list is used to calculate the position of 'end' or
              -- 'until' so that it aligns with the head keyword.
              table.insert(positionList, {indent, string.len(trimmedLine) - 1, line = lineNumber}) 
            end
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
            -- This test prevents an end statement from decreasing the current indentation level 
            -- in the case of a one-line block. This wouldn't be necessary if we just matched the 
            -- number of increasers minus the number of decreasers.
            currIndent = pos[1] - INDENT_LEVEL
          end
          nextIndent = nextIndent - pos[2] - INDENT_LEVEL
        else
          -- If the token is not a keyword, don't change variable previousToken
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
        s, e = string.find(line, "^=*%[", i + 1) 
        if s then
          equalSigns = e - s -- number of equal signs found
          inLongString = true
        end
      elseif currChar == "]" and inLongString then
        -- Possibly the end of a long string. Find the number of equal signs before this point
        -- and compare with the equal signs found earlier when the opening round bracket was
        -- found
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
    elseif skipCurrentCharacter then
      skipCurrentCharacter = false
    end
  end

  if startsWithString or line:find("^[ \t]*[\r\n]$") then
    -- Don't indent the line if it starts with a string
    indentedFile:write(trimmedLine) 
    -- The gsub below is a hack for SciTE and the console. CRLF characters tend
    -- to insert an extra line even with buffering switched off with io.stdout:setvbuf 'no'
    -- It also makes sure that files with CR line endings will have all their
    -- content printed.
    io.write((trimmedLine:gsub("\r\n?", '\n'))) 
  else
    if #positionList > 0 then
      nextIndent = positionList[#positionList][1]
    end
    if addExtraLevel then
      -- increase the indentation by EXTRA_LEVEL spaces if the line ends with
      -- 'and', 'or' or '='
      indentedLine = string.rep(" ", currIndent + EXTRA_LEVEL) .. trimmedLine
      io.write((indentedLine:gsub("\r\n?", '\n'))) 
      indentedFile:write(indentedLine) 
    else
      -- Otherwise indent using the current indentation
      indentedLine = string.rep(" ", currIndent) .. trimmedLine
      io.write((indentedLine:gsub("\r\n?", '\n'))) 
      indentedFile:write(indentedLine) 
    end
  end
end

indentedFile:close() 
assert(os.remove(arg[1])) -- Deletes the original file
assert(os.rename("temp-file", arg[1]))
assert(not (inLongString or inSingleQuotedString or inDoubleQuotedString), 
  "You have unterminated strings") 
assert(#positionList == 0, "You have unfinished blocks")

