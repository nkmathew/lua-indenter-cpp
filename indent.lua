
function string:charAt(index)
    return string.sub(self, index, index)
end

function isIncreaser(token)
    return token == "if" or  token =="function" or  
    token == "while" or  token == "repeat" or  token == "do" or
    token == "for"
end

function isDecreaser(token)
    return token == "end" or  token == "until"
end

function appendChar(str, prevChar, currChar, nextChar, prevPrevChar, i)
    -- The function concatenates the current character to the passed string
    -- selectively so that in the end the whole string looks trimmed.
    -- Beware of hacks below.
    -----------------------------------------------------------------------------------
    -- Comment this region if you don't like spaces before and after operators
    prevPrevPrevChar = ""
    if i > 3 then
        prevPrevPrevChar = str:charAt(i - 3)
    end
    local trimmedStr = str
    if not prevChar:find("[\t ]") and i ~= 1 and not currChar:find("[%])[.:]") then
             -- and not (prevPrevPrevChar == )
        -- If there's no space before this operator, add one
        if (prevChar:find("[-/+*^,)]") or currChar:find("[%^>%<-/~+*]")) and not currChar:find("[ \t]") and
            not (prevChar == ")" and currChar == ",")then
            -- Add a space before and after operators(+, -, *, /) and the operands only if there
            -- isn't a space before it
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
    if not currChar:find("[\t ]") and currChar ~= "]" then
        -- If the next character after the operator is not a space add
        -- one. If the current character is a square bracket, don't add a
        -- space because it is part of a long string or comment
        --
        if prevPrevChar:find("[~>%<=]") and prevChar == "=" then
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

-- Remove extra whitespace without messing with strings.
-- This is done the manual way, i.e. walking the string character
-- by character and only appending to trimmedStr if the previous character
-- is not a space or a tab.
escaped = false
inSingleQuotedString = false
inDoubleQuotedString = false
inLongString = false
-- A long string can only be closed with the same number of equal signs.

local equalSigns = 0
local lineNumber = 0
local currIndent = 0
local nextIndent = 0
positionList = {}
bracketList = {{0,0 ,line = 0}}
indentedCode = ""
lastToken = ""
token = ""
indentedFile = assert(io.open("indented-file.lua", "w"))

INDENT_LEVEL = 2
-- In case the line ends with an 'or' or 'and' the next line is indented by EXTRA_LEVEL more
-- spaces so that return values don't align with the 'return' keyword.
EXTRA_LEVEL = 0

foundLogicalOperator = false
rawFile = assert(io.open(arg[1], "r"))
token = ""
for str in rawFile:lines() do
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
        
        if str:find("^[ \t]*-%-", i) and not (inSingleQuotedString or inDoubleQuotedString or inLongString) then
            -- If it finds a line comment, it should preserve the comment and all the 
            -- space before it
            inLineComment = true
            if str:find("^[ \t]*-%-") then
                startsWithString =  true
            end
        end
        if inSingleQuotedString or inDoubleQuotedString or inLongString or inLineComment then
            -- Append the characters the way they come so that the string/comment does not change
            trimmedStr = trimmedStr .. currChar
            foundLogicalOperator = false
            --print("-->in string", lineNumber, i, escaped)
        else
            foundLogicalOperator = str:find("[ )]and *$") or  str:find("[ )]or *$")
            trimmedStr = appendChar(trimmedStr, prevChar, currChar, nextChar, prevPrevChar, i)
            ---------------------------------------------------------------
            if currChar:find("[({]") then
                table.insert(bracketList, (currIndent + i))
                trimmedLength = string.len(trimmedStr)
                table.insert(positionList, {(currIndent + trimmedLength), trimmedLength})
                --print("+++++found opening bracket at: ", currIndent, trimmedLength)
            elseif currChar:find("[)}]") then
                table.remove(bracketList)
                pos = table.remove(positionList)
                if #positionList > 0 then
                    nextIndent = nextIndent - pos[1]
                else
                    nextIndent = 0
                end
                --print("+++++found closing bracket at: ", nextIndent, currIndent, trimmedLength)
            end
            ---------------------------------------------------------------
            previousToken = token
            if (prevChar:find("[ \t>%<=+-*/^]") or prevChar == "") and currChar:find("[eiuwfdr]") then
                -- Test the characters that keywords start with instead of
                -- assuming that there'll always be a space before a keyword.
                substr = string.gsub(string.sub(str, i), "^[\t ]*", "") -- Slice to the end and strip leading whitespace
                _, nextSpace = string.find(substr, "[ ({]") -- Find the first space. The asterisk caters for a no match case
                token = string.sub(substr, 1, nextSpace) -- Get the token/keyword/function name
                token = string.gsub(token, "[%() \t\n]", "")
            --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            -- Indentation level is determined here.
                if isIncreaser(token) and token ~= "" then
                    -- We add the current accumulated string length so that the some blocks like
                    -- anonymous functions have their 'end' aligning with the 'function'
                    nextIndent = nextIndent + (string.len(trimmedStr) - 1) + INDENT_LEVEL
                    --print("next indent: ", nextIndent, lineNumber, )
                    -- We also need to store the string length at that time so that when it comes
                    -- to restoring the level, we can just subtract from the current level.
                    -- Substract 1 from the string length since indexing starts from 1
                    if not ((previousToken == "for" or previousToken == "while") and token == "do") then
                        table.insert(positionList, {nextIndent, string.len(trimmedStr) -1, line = lineNumber})
                    --print("--", previousToken, token)
                    --print(string.format("--increaser: '%s'", token))
                    end
                elseif token == "elseif" or token == "else" then
                    currIndent = currIndent - INDENT_LEVEL
                elseif isDecreaser(token) and token ~= "" then
                    --print(string.format("--decreaser: '%s'", token))
                    pos = table.remove(positionList)
                    assert(pos, string.format("Excess 'end' statements: (%d, %d)", lineNumber, i))
                    nextIndent = nextIndent - pos[2] - INDENT_LEVEL
                    --print("Next indent: ", pos[2], token, lineNumber)
                    currIndent = pos[1] - INDENT_LEVEL
                else
                    token = previousToken
                end
            end
            --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        end
        if not escaped then
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
    
    if  startsWithString then
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

