/**

@Started: 22:30 22nd December 2013
@Date: 30th December 2013
@Home: https://gist.github.com/nkmathew/8181368
@Cloning: https://gist.github.com/8181368.git
@Author: nkmathew <kipkoechmathew@gmail.com>

This program is the same as the one [here](https://gist.github.com/nkmathew/7969358).
only, it's not in Lua(obviously).
It's still a Lua indenter and is almost as good, if not better, as the Lua version.
It's faster than the Lua version(used every trick in the book to make it fast) by
between 0.6 and 1.2 seconds(YMMV).

I've tested with every .lua in my computer and it only choked on one file, some
689KB file that comes with ZeroBraneStudio(luxiniaapi.lua). Unfortunately, the file
was too big for me to pinpoint the cause of the segfault. Otherwise, it should be
pretty reliable as long as it's not indenting some 500KB+ autogenerated file.

**/

#include <fstream>
#include <iostream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <cstdio>
#include <algorithm>
#include <cerrno>

// ~~~~~~~~~~~~~~~~~~~~~~~~~[ Structures and Global Variables ]~~~~~~~~~~~~~~~~~~~~~~~~

// Stores the indentation levels for each token/keyword found
struct TokenCoord {
  int line; // Used to handle one-liners
  int offset;
  int indent_level;
  int restorer;  // Restores the indentation level to what it was before.
  std::string token;
};

// The struct holds the pointers to the start and end positions of the lines in
//the files. The lines are going to be retrieved on demand.
struct StringRef {
  StringRef(std::string::const_iterator start, std::string::const_iterator end)
    : start_pos(start), end_pos(end) {}
  StringRef() : start_pos(0), end_pos(0) {} // default constructor
  std::string::const_iterator start_pos;
  std::string::const_iterator end_pos;
};

bool ALIGN_BRACKETS    = false,
     BASIC_INDENTATION = true,
     COMPACT           = true,
     INDENT_COMMENTS   = false,
     OUTPUT            = true,
     NO_EXTRA_LEVEL    = false;

int INDENT_LEVEL = 2,
    EXTRA_LEVEL  = 7;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Function Prototypes ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

std::string append_char(std::string, std::string, std::string, std::string, int, std::string);
bool ends_with(const std::string *, std::string);
bool is_decreaser(const std::string *);
bool is_increaser(const std::string *);
bool is_line_comment(const std::string *, int);
bool equals_any(std::string, std::string);
void indent_code(std::string *, std::fstream *f = NULL);
int file_length(const char *);
int substring_count(const std::string *, const std::string *);
std::vector<StringRef> split(std::string *, const std::string sep = " ", bool preserve = true);
std::string remove_chars(std::string, std::string);
std::string slurp_file_contents(const char *fname);
std::string strip_leading_whitespace(std::string *);
void write_string(std::fstream *, std::string *);

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

bool ends_with(const std::string *str, std::string substr) {
  // Checks if a string ends with another string.
  int str_len    = str->length();
  int substr_len = substr.length();
  if (str_len < substr_len) {
    return false;
  } else {
    return str->substr(str_len - substr_len, -1) == substr;
  }
}

std::string remove_chars(std::string str, std::string replacements) {
  // Deletes the specified characters from the string. Used to remove
  // any characters attached to keywords, like commas, brackets etc
  std::string result = "";
  for (int i = 0; i < str.length(); i++) {
    std::string curr_char(1, str.at(i));
    int match_pos = replacements.find_first_of(curr_char);
    if (match_pos == std::string::npos) {
      result += curr_char;
    }
  }
  return result;
}

std::string strip_leading_whitespace(std::string *str) {
  int first_non_space = str->find_first_not_of("\t ");
  first_non_space = (first_non_space == std::string::npos) ?
                    str->length() : first_non_space;
  return str->substr(first_non_space, -1); // Return the rest of the string
}


int file_length(const char *fname) {
  // Returns the number of characters in the file. The value returned will
  // determine the initial size of the array that's going to store the file's
  // contents. It seeks to the end of the file and returns that position as the
  // length
  std::fstream open_file(fname, std::ios::in);
  if (open_file) {
    open_file.seekg(0, std::ios::end);
    const int n_chars = open_file.tellg();
    open_file.close();
    return n_chars;
  } else {
    // Bad filename or some other I/O error
    std::printf("Exiting: `%s': %s\n", fname, std::strerror(errno));
    exit(1);
    return -1;
  }
}

int substring_count(const std::string *str, const std::string *substr) {
  // Count the number of occurrences of a substring in a string. It's going
  // to be used to determine an appropriate initial size for the vector that's
  // going to hold the lines in the file
  const int substr_len = substr->length();
  int count = 0;
  // npos is the value returned when no match is found. It's the same as
  // (size_t)(-1)
  int next_pos = str->find(*substr);
  while (next_pos != std::string::npos) {
    count++;
    next_pos = next_pos + substr_len;
    next_pos = str->find(*substr, next_pos);
  }
  return count;
}

std::string slurp_file_contents(const char *fname) {
  // Reads the whole file into a dynamic array character by character
  // and then uses std::string's constructor to create a string(probably not the
  // most elegant solution)
  int length = file_length(fname);
  char *char_list = new char[length + 1];
  std::fstream File(fname, std::ios::in | std::ios::binary);
  // For some reason, the program is not able to detect CRLF line endings
  // without std::ios::binary yet it can detect both CR and LF separately
  int i;
  for (i = 0; i < length; i++) {
    // Copy character by character. getline doesn't seem to work here
    char_list[i] = File.get();
  }
  // You'll get unwanted/garbage at the end of the string without the null
  // character after conversion std::string
  char_list[length] = '\0';
  File.close();
  std::string file_str(char_list);
  delete[] char_list;
  return file_str;
}

std::vector<StringRef> split(std::string *str, const std::string sep,
                             bool preserve) {
  // Walk the whole string storing the start and end positions of the
  // substrings in a vector to be used later. I borrowed StringRef from
  // a good answer in SO. My original implementation was very inefficient
  // with 200KB+ files. It involved copying the substrings to the vector and
  // returning it. It was so slow that it would take 5 more seconds to split
  // a 700KB file than the Lua version.
  const int vector_size = substring_count(str, &sep) + 1;
  const int sep_length = sep.length();
  // The number of occurrences of the separator determines the initial size of
  // the vector.
  std::vector<StringRef> split_portions(vector_size);
  int next_pos = 0;
  int  prev_pos = 0;
  int index = 0;
  std::string::const_iterator it = str->begin();
  while (1) {  // Loop forever
    next_pos = str->find(sep, prev_pos);
    if (next_pos == std::string::npos) {
      // If a match can nolonger be found, add the rest of the string and exit
      // from the the loop. The last portion of the string would have been lost
      // if the condition had been placed in the loop's head.
      StringRef string_ptr_pos(it + prev_pos, str->end());
      split_portions[index] = string_ptr_pos;
      break;
    } else {
      if (preserve) {
        // Include the separator in the sliced string hence preserving it. Saves
        // you the trouble of mapping the line ending back like I did in the Lua
        // version
        StringRef string_ptr_pos(it + prev_pos, it + (next_pos + sep_length));
        split_portions[index] = string_ptr_pos;
      } else {
        StringRef string_ptr_pos(it + prev_pos, it + next_pos);
        split_portions[index] = string_ptr_pos;
      }
      index++;
      prev_pos = next_pos + sep_length;
    }
  }
  return split_portions;
}

inline bool equals_any(std::string str, std::string match_chars) {
  // Tests if one of the characters in `match_chars` is in `str`
  // Since this operation is done so many times here, it had to be
  // in a function in order to reduce the length of expressions
  // like in the ones in `append_char`. It's the most called function
  // in this program
  return str.find_first_of(match_chars) != std::string::npos;
}

std::string append_char(std::string prev_char, std::string
                        curr_char, std::string next_char,
                        std::string prev_prev_char, int i,
                        std::string prev_prev_prev_char) {
  std::string str   = "";
  std::string digit = "0123456789";
  if ((!equals_any(prev_char, "\t ")  // No need to add a space if there's already one
       && i != 0 // Don't add a space if the operator is the first character
       && !equals_any(curr_char, "])[:\r\n"))) { // Don't add space if at the end of the line
    if (equals_any(curr_char, "%^><-/~+*")
        && !(equals_any(curr_char, "+-") && equals_any(prev_char, "eE") && equals_any(prev_prev_char, digit))
        && !(equals_any(prev_char, "({%[=,"))) { // Don't add space after opening bracket
      // Add a space before operators(+, -, *, /) and the operands
      if (!(curr_char == "-" && prev_char == "-")) {
        // The test prevents it from splitting the two dash signs
        // that indicate a comment
        str += " ";
      }
    } else if (curr_char == "=" && !equals_any(prev_char, "=><~")) {
      // Add a space before == and = without splitting ==
      str += " ";
    } else if (curr_char == "." && !equals_any(prev_char, ".){}(,")
               && next_char == ".") {
      // Add a space before ..
      str += " ";
    }
  }
  if (!equals_any(curr_char, "])} \r\n\t")) {
    // If the next character after the operator is not a space add
    // one. If the current character is a square bracket, don't add a
    // space because it is part of a long string or comment
    if (equals_any(prev_char, "-+/*^,)%")
        && !(equals_any(prev_prev_char, "(=/*")
             && equals_any(prev_char, "-+")) // Don't split sth like `print(-3)`
        && !(equals_any(prev_prev_prev_char, ",")
             && equals_any(prev_char, "-+")) // Don't split `print(-3, -3)`
        && !(equals_any(prev_prev_prev_char, "=*^/")
             && equals_any(prev_char, "-+")) // Don't split sign in `var = -3`
        && !(curr_char == "-" && equals_any(prev_char, "-+*/^")) // Don't split comment markers
        && !(prev_char == "-" && curr_char == "[") // Don't put a space btw square bracket and long comment marker
        && !(equals_any(prev_char, "+-") && equals_any(prev_prev_char, "eE") && equals_any(prev_prev_prev_char, digit))
        && !(prev_char == ")" && equals_any(curr_char, ":,[+-*/=^")) // Don't split sth like ("This"):find("i")
        && !(prev_char == ")" && curr_char == "." && next_char != ".")) { // split sth like (func()).."\n"
      // Add a space after operators(+, -, *, /) and the operands
      str += " ";
    } else if (equals_any(prev_prev_char, "~><=") && prev_char == "=" &&
               curr_char != " ") {
      // Add a space after <=, =>, ~=, ==
      str += " ";
    } else if (curr_char != "=" && equals_any(prev_char, "><")) {
      // Add a space after <, > without affecting <=, =>
      str += " ";
    } else if (prev_char == "=" && !(equals_any(prev_prev_char, "<>~=")) &&
               curr_char != "=") {
      // Add a space after = without splitting ==
      str += " ";
    } else if (curr_char != "." && prev_char == "." && prev_prev_char == ".") {
      // Add a space after ..
      str += " ";
    }
  }
  if (!(equals_any(prev_char, "\t ") && equals_any(curr_char, "\t "))
      && !((prev_char == "") && equals_any(curr_char, "\t ")) // Don't copy any leading spaces
      && !(equals_any(prev_char, "({[") && equals_any(curr_char, "\t "))
      && !(equals_any(next_char, "})],") && equals_any(curr_char, "\t "))) {
    // Trimming happens here. We only copy the character if the previous
    // character is not a space or a tab or a zero length string that way it
    // strips all whitespace before the string. The last part of the test
    // expression makes sure all trailing spaces are removed by not copying the
    // first whitespace
    str += curr_char;
  }
  return str;
}

bool is_line_comment(const std::string *str, int start_pos) {
  // Find start of non whitespace
  int space_end = str->find_first_not_of(" \t", start_pos);
  space_end = (space_end == std::string::npos) ? 0 : space_end;
  if (str->substr(space_end, 2) != "--") {
    // False if it doesn't start with --
    return false;
  } else {
    space_end += 2;
    if ((*str)[space_end] == '[') {
      // Could possibly be a long comment, investigate some more
      if ((*str)[space_end + 1] == '[') {
        // long comment found with no equal signs between the brackets
        return false;
      } else if ((*str)[space_end + 1] == '=') {
        // Walk the string starting from the square bracket stopping
        // at the first square bracket or any character that is not an equal
        // sign
        for (space_end++; space_end < str->length(); space_end++) {
          if ((*str)[space_end] == '[') {
            return false;
          } else if ((*str)[space_end] != '=') {
            // If there's some other character other than the equal sign between
            // the square brackets, it means that it's not a valid long comment,
            // hence true is returned
            return true;
          }
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
  }
}

bool is_increaser(const std::string *token) {
  return *token == "if" || *token == "function" || *token == "repeat" ||
         *token == "while" || *token == "do" || *token == "for";
}

bool is_decreaser(const std::string *token) {
  return *token == "end" || *token == "until";
}

void write_string(std::fstream *out_file, std::string *str) {
  // Uses the `put` function to write a whole string. Using `write` would
  // have required a little bit more effort(unnecessary).
  for (std::string::const_iterator it = str->begin(); it != str->end(); ++it) {
    out_file->put(*it);
  }
}

// Help message. Avoiding multiline strings so that it can compile with c99
std::string usage = 
"lua-indenter.lua <filename> [[--no-basic] [--indent-comments] [--no-compact] [--align-brackets]]  \n"
"  \n"
"--indent-comments, -ic  ## Causes line comments(not long comments) to be indented like every other line.  \n"
"                           It's false by default in order to preseve any deliberate comment layout.  \n"
"\n"
"--no-compact, -nc       ## Instructs the program to indent without messing with the  \n"
"                           program layout like aligned equal signs or aligned tables(like the `network`  \n"
"                           table below)  \n"
"  \n"
"--align-brackets, -ab   ## Aligns brackets like this:  \n"
"                            network = {{name = \"grauna\",  IP = \"210.26.30.34\"},  \n"
"                                       {name = \"arraial\", IP = \"210.26.30.23\"},  \n"
"                                       {name = \"lua\",     IP = \"210.26.23.12\"},  \n"
"                                       {name = \"derain\",  IP = \"210.26.23.20\"},  \n"
"                                       }  \n"
"                            when ALIGN_BRACKETS is false, brackets will cause an  \n"
"                            increase in the indentation level by INDENT_LEVEL spaces.  \n"
"  \n"
"--no-basic, -nb        ## Strives to align the head keyword with the terminating  \n"
"                            keyword no matter where it is in the line  \n"
"                          It's default status is false. Using this option will give  \n"
"                          you an indentation like the hypotenuse function mentioned earlier.  \n"
"\n"
"--no-output, -no      ## Suppress outputting of the indented code.  \n"
"\n"
"\n"
"--no-extra-level, -ne ## Don't add EXTRA_LEVEL spaces to the indent level if  \n"
"                         the line ends with 'and', 'or' or '='. It can make  \n"
"                         some lines like these ones below clearer:  \n"
"\n"
"                              return token == \"end\" or\n"
"                                     token == \"until\"\n"
"                        and at the same time more confusing when the placement  \n"
"                        of the logical operators is not consistent. \n"
"\n"
"                              retval = first_val or\n"
"                                       second_val\n"
"                              or third_val\n"
"\n"
"                        The indentation will improve if the 'or' is placed at  \n"
"                        the end of the second line:\n"
"\n"
"                              retval = first_val or\n"
"                                     second_val or\n"
"                                     third_val\n\n\n";


int main(int argc, char *argv[]) {
  // process commandline arguments
  if (argc >= 2) {
    std::string fname = argv[1];
    for (int i = argc - 1; i >= 0; i--) {
      if ((strcmp(argv[i], "-no") == 0) ||
          (strcmp(argv[i], "-no-output") == 0)) {
        OUTPUT = false;
      }
      if ((strcmp(argv[i], "-nb") == 0) ||
          (strcmp(argv[i], "-no-basic") == 0)) {
        BASIC_INDENTATION = false;
      }
      if ((strcmp(argv[i], "-nc") == 0) ||
          (strcmp(argv[i], "-no-compact") == 0)) {
        COMPACT = false;
      }
      if ((strcmp(argv[i], "-ic") == 0) ||
          (strcmp(argv[i], "-indent-comments") == 0)) {
        INDENT_COMMENTS = true;
      }
      if ((strcmp(argv[i], "-ab") == 0) ||
          (strcmp(argv[i], "-align-brackets") == 0)) {
        ALIGN_BRACKETS = true;
      }
      if ((strcmp(argv[i], "-ne") == 0) ||
          (strcmp(argv[i], "-no-extra-level") == 0)) {
        NO_EXTRA_LEVEL = true;
      }
    }

    if (NO_EXTRA_LEVEL) {
      EXTRA_LEVEL = 0;
    }
    std::string contents = slurp_file_contents(fname.c_str());
    std::fstream temp_file("temp-file.lua", std::ios::out | std::ios::binary);
    //std::fprintf(stderr, "-- Indenting `%s'. . .\n", fname.c_str());
    indent_code(&contents, &temp_file);
    temp_file.close();

    std::remove(fname.c_str());
    std::rename("temp-file.lua", fname.c_str());
  } else {
    std::cout << usage << std::endl;
  }
  return 0;
}

void indent_code(std::string *raw_code, std::fstream *indented_file) {
  const std::string CR = "\r";
  const std::string LF = "\n";
  const std::string CRLF = CR + LF;

  // Determine the line ending to be used for splitting. Default is LF
  std::string line_ending = "\n";
  if (raw_code->find(CRLF) != std::string::npos) {
    line_ending = CRLF;
  } else if (raw_code->find(CR) != std::string::npos) {
    line_ending = CR;
  }

  // Store the substrings(lines) in a vector.
  std::vector<StringRef> code_lines = split(raw_code, line_ending);

  // state variables:
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  int n_lines       = code_lines.size(),
      next_indent   = 0,
      curr_indent   = 0,
      equal_signs   = -999,
      bracket_count = 0;

  bool escaped                 = false,
       in_long_string          = false,
       in_single_quoted_string = false,
       in_double_quoted_string = false,
       found_logical_operator  = false,
       for_keyword             = false,
       while_keyword           = false;

  std::vector<TokenCoord> token_locations;  // It'll act like a stack
  std::string token = "";

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  for (int line_number      = 0; line_number < n_lines; line_number++) {
    bool add_extra_level    = found_logical_operator;
    bool in_line_comment    = false;
    bool starts_with_string = in_single_quoted_string || in_double_quoted_string
                              || in_long_string;

    curr_indent = next_indent;
    std::string trimmed_line; // The line to be appended character by character

    // Get the iterator.
    StringRef curr_line = code_lines[line_number];

    // Create a string from the iterator in the vector
    std::string line   = std::string(curr_line.start_pos, curr_line.end_pos);
    int spaces_removed = line.length();
    if (!starts_with_string && !(is_line_comment(&line, 0) && !INDENT_COMMENTS)) {
      line = strip_leading_whitespace(&line);
      spaces_removed -= line.length();
    }

    int line_length = line.length();
    trimmed_line.reserve(line_length); // performance trick that IMO never works

    for (int offset = 0; offset < line_length; offset++) {
      std::string curr_char      = std::string(1, line[offset]);
      std::string next_char      = (offset > (line_length - 2)) ? "" : line.substr(offset + 1, 1);
      std::string prev_char      = (offset == 0) ? "" : line.substr(offset - 1, 1);
      std::string prev_prev_char = (offset < 2) ? "" :
                                   line.substr(offset - 2, 1);

      if (escaped) {
        // Skip the current character if the previous character is a backslash
        // that itself hasn't been escaped.
        escaped = false;
        trimmed_line += curr_char;
        continue;
      }
      if (curr_char == "\\" && (!in_long_string)) {
        escaped = true;
      }

      if (!(in_single_quoted_string || in_long_string || in_double_quoted_string)) {
        if (is_line_comment(&line, 0) || (line.find("#!") == 0)) {
          // This is a comment line. Preserve all whitespace before the comment
          in_line_comment = true;
          if (INDENT_COMMENTS) {
            starts_with_string = false;
          } else {
            starts_with_string = true;
          }
        }
        if (offset != 0 && is_line_comment(&line, offset)) {
          // Detect a line comment within the line
          in_line_comment = true;
        }
      }
      if (in_single_quoted_string || in_double_quoted_string || in_long_string
          || in_line_comment) {
        trimmed_line += curr_char;
        found_logical_operator = false;
      } else {
        if (COMPACT) {
          std::string prev_prev_prev_char = "";
          int t_len = trimmed_line.length();
          if (trimmed_line.length() >= 3) {
            prev_prev_prev_char = trimmed_line[t_len - 3];
          }
          std::string char1 = (t_len < 1) ? "" :
                              trimmed_line.substr(t_len - 1, 1);
          std::string char2 = (t_len < 2) ? "" :
                              trimmed_line.substr(t_len - 2, 1);

          trimmed_line += append_char(char1, curr_char, next_char,
                                      char2, offset, prev_prev_prev_char);
        } else {
          trimmed_line += curr_char;
        }

        TokenCoord prev_pos; // Holds the last location pushed to the vector

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~[ handle bracket indentation ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if (equals_any(curr_char, "({")) {
          bracket_count++;
          int trimmed_length = trimmed_line.length();
          if (ALIGN_BRACKETS) {
            TokenCoord curr_pos = {line_number, offset, curr_indent +
                                   trimmed_length, trimmed_length, curr_char
                                  };
            token_locations.push_back(curr_pos); // Add to the vector
          } else {
            next_indent += INDENT_LEVEL;
            TokenCoord curr_pos = {line_number, offset, next_indent,
                                   INDENT_LEVEL, curr_char
                                  };
            token_locations.push_back(curr_pos); // Add to the vector
          }
        } else if (equals_any(curr_char, ")}")) {
          if (!(!token_locations.empty() and (bracket_count > 0))) {
            // An unmatched bracket found, issue warning and exit.
            std::fprintf(stderr, "Excess bracket `%s' around (%d, %d). Exiting. . .\n",
                         curr_char.c_str(), line_number + 1, spaces_removed + offset + 1);
            std::exit(1);
          }
          bracket_count--;
          prev_pos = token_locations.back();
          std::string correct_closer = "";
          if (prev_pos.token == "(") {
            correct_closer = ")";
          } else if (prev_pos.token == "{") {
            correct_closer = "}";
          }
          if (curr_char != correct_closer) {
            std::fprintf(stderr, "Bracket `%s' at (%d, %d) does not match `%s' at (%d, %d)\n",
                         prev_pos.token.c_str(), prev_pos.line + 1, prev_pos.offset + 1,
                         curr_char.c_str(), line_number + 1, offset + 1);
            std::exit(1);
          }
          token_locations.pop_back(); // remove from vector. Doesn't really shrink the vector.
          if (!token_locations.empty()) {
            if (!ALIGN_BRACKETS) {
              next_indent -= prev_pos.restorer;
              if (offset == 0) {
                curr_indent -= INDENT_LEVEL;
              }
            }
          } else {
            // If all blocks are finished, set the next line's indentation level
            // to zero.
            next_indent = 0;
            if (!ALIGN_BRACKETS) {
              // Make sure the closing bracket has a less indent than the block
              // statements
              if (offset == 0) {
                curr_indent -= INDENT_LEVEL;
              }
            }
          }
        }
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        std::string previous_token = token;
        if ((equals_any(prev_char, "\t ><=+-*/^(){;,\"']") || prev_char == "") &&
            equals_any(curr_char, "eifdruw")) {
          // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Extract token ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
          std::string substr = line.substr(offset, 10); // No keyword is more than 10 characters
          int token_end = substr.find_first_of(" [%(})\t\n,{;\r-]");
          token = substr.substr(0, token_end);
          token = remove_chars(token, "[] %(})\t\n,{\"';\r-"); // remove non-identifier characters.
          // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
          if (is_increaser(&token) && token != "") {
            // variables for_keyword and while_keyword safeguards against
            // indenting both 'do' and 'for' and enables correct indentation of
            // 'do' keywords in different lines from the 'for' or 'while' keyword.
            if (token == "for") {
              for_keyword = true;
            } else if (token == "while") {
              while_keyword = true;
            }

            if (!((for_keyword || while_keyword) && token == "do")) {
              if (BASIC_INDENTATION) {
                next_indent += INDENT_LEVEL; // bump indent level
                TokenCoord curr_pos = {line_number, offset, next_indent, 0, token};
                token_locations.push_back(curr_pos); // store the location in the vector
              } else {
                int indent = curr_indent + (trimmed_line.length() - 1) +
                             INDENT_LEVEL;
                TokenCoord curr_pos = {line_number, offset, indent,
                                       (static_cast<int>(trimmed_line.length()) - 1),
                                       token
                                      };
                token_locations.push_back(curr_pos); // Add the struct to the end of the vector.
              }
            }
            // ~~~~~~~~~~~~~~~~~~~~[ Handle extended for/while constructs ]~~~~~~~~~~~~~~~~~~~
            if (token == "do" && for_keyword) {
              for_keyword = false;
            } else if (token == "do" && while_keyword) {
              while_keyword = false;
            }
            // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

          } else if (token == "elseif" || token == "else") {
            prev_pos = token_locations.back();
            if (prev_pos.line != line_number) {
              // Decrease the indent level only if not in a one-liner
              curr_indent -= INDENT_LEVEL;
            }
          } else if (is_decreaser(&token) && token != "") {
            bool empty = token_locations.empty();
            if (empty) {
              // Excess end-of-block statement found, issue warning and exit. Failure
              // to exit will result in a segfault(duh!)
              std::fprintf(stderr, "Unmatched `%s' statement at (%d, %d). Exiting. . .\n",
                           token.c_str(), line_number + 1, offset);
              std::exit(1);
            }
            prev_pos = token_locations.back();
            token_locations.pop_back();
            if (prev_pos.line != line_number) {
              // The test prevents end statements if one-liner blocks from
              // affecting the indentation
              curr_indent = prev_pos.indent_level - INDENT_LEVEL;
            }
            if (BASIC_INDENTATION) {
              next_indent = next_indent - prev_pos.restorer - INDENT_LEVEL;
            } else if (prev_pos.line != line_number) {
              next_indent = next_indent - INDENT_LEVEL;
            }
          } else {
            token = previous_token;
          }
        }
      }
      // ~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Handle quoted strings ]~~~~~~~~~~~~~~~~~~~~~~~
      // NOTE: strings are handled at the end of the loop so that spacing operators
      // can happen when e.g. a quote comes after an equal sign.
      if (!in_line_comment) {
        if (curr_char == "'" && !(in_double_quoted_string || in_long_string)) {
          //std::printf("-- Found single quoted string at LINE: %d", line_number);
          if (in_single_quoted_string) {
            in_single_quoted_string = false;
          } else {
            in_single_quoted_string = true;
          }
        }
        if (curr_char == "\"" && !(in_single_quoted_string || in_long_string)) {
          if (in_double_quoted_string) {
            in_double_quoted_string = false;
          } else {
            in_double_quoted_string = true;
          }
        }
      }
      // ~~~~~~~~~~~~~~~~~~[ Handle Long comments/strings ]~~~~~~--[[   ]]~~~~~~~~~~
      // Since we don't have regular expressions in STL. We'll have to do it
      // char by char
      if (curr_char == "[" && !(in_long_string || in_single_quoted_string ||
                                in_double_quoted_string || in_line_comment)) {
        int n_equal_signs = -999;
        if (next_char == "[") {
          n_equal_signs = 0;
        } else if (next_char == "=") {
          n_equal_signs = line.find("[", offset + 1);
          if (n_equal_signs != std::string::npos) {
            n_equal_signs = n_equal_signs - offset - 1;
          }
        }
        if (n_equal_signs != -999) {
          in_long_string = true;
          equal_signs    = n_equal_signs;
        }
      } else if (curr_char == "]" && in_long_string) {
        int n_equal_signs = -999;
        if (prev_char == "]") {
          n_equal_signs = 0;
        } else if (prev_char == "=") {
          int count = 0;
          for (int i = offset - 1; i >= 0; i--) {
            if (!(line[i] == ']' || line[i] == '=')) {
              count = -999;
              break;
            } else {
              if (line[i] != ']' && i == 0) {
                count = -999;
              } else if (line[i] == ']') {
                break;
              } else {
                count++;
              }
            }
          }
          n_equal_signs = count;
        }
        if (n_equal_signs == equal_signs) {
          in_long_string = false;
        }
      }
    }

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if (!(in_line_comment || in_single_quoted_string || in_double_quoted_string ||
          in_long_string)) {
      // check if the line ends with a logical operator. If so, it'll determine whether
      // EXTRA_LEVEL spaces will be added
      int last_space = line.find_last_not_of("\r\n\t ");
      last_space = (last_space == std::string::npos) ? line.length() - 1 : last_space;
      last_space = last_space - 3;
      last_space = (last_space < 0) ? 0 : last_space;
      std::string last_part = line.substr(last_space, 4);
      last_part = remove_chars(last_part, "\r\n");
      found_logical_operator = ends_with(&last_part, " and") ||
                               ends_with(&last_part, " or") ||
                               ends_with(&last_part, "=");
    }

    // ~~~~~~~~~~~~~~~~~~~~~~~~[ Indent the line/Write to file ]~~~~~~~~~~~~~~~~~~~~~~~~~~
    if (starts_with_string || equals_any(trimmed_line.substr(0, 1), "\r\n")) {
      if (OUTPUT) {
        std::cout << remove_chars(trimmed_line, "\r\n") << std::endl;
      }
      write_string(indented_file, &trimmed_line);
    } else {
      if (!token_locations.empty()) {
        next_indent = token_locations.back().indent_level;
      } else {
        next_indent = 0;
      }
      if (add_extra_level) {
        std::string indented_line(curr_indent + EXTRA_LEVEL, ' ');
        indented_line += trimmed_line;
        if (OUTPUT) {
          std::cout << remove_chars(indented_line, "\r\n") << std::endl;
        }
        write_string(indented_file, &indented_line);
      } else {
        std::string indented_line(curr_indent, ' ');
        indented_line += trimmed_line;
        if (OUTPUT) {
          std::cout << remove_chars(indented_line, "\r\n") << std::endl;
        }
        write_string(indented_file, &indented_line);
      }
    }
  }
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Issue warnings ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if (in_long_string) {
    std::fprintf(stderr, "-- You have an unterminated long string quoted string\n");
  }
  if (in_single_quoted_string) {
    std::fprintf(stderr, "-- You have an unterminated single quoted string\n");
  }
  if (in_double_quoted_string) {
    std::fprintf(stderr, "-- You have an unterminated double quoted string\n");
  }
  if (!token_locations.empty()) {
    std::fprintf(stderr, "-- You have unfinished blocks\n");
    int size = token_locations.size();
    if (size > 0) {
      // Print the position of every token/keyword that hasn't been closed.
      for (int i = size - 1; i >= 0; i--) {
        TokenCoord ti = token_locations[i];
        std::fprintf(stderr, "      LINE: (%d, %d) '%s'\n", ti.line + 1,
                     ti.offset, token.c_str());
      }
    }
  }
}

