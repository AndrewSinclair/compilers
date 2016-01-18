/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
 int num_comments = 0;
 bool in_string = false;

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ASSIGN          <-
LE              <=
NEWLINE         \n
START_COMMENT   \(\*
END_COMMENT     \*\)
LINE_COMMENT    --[^\n]*

%START          COMMENT STRING SINGLE_COMMENT

%%

 /*
  *  Nested comments
  */
<INITIAL>{START_COMMENT}         { BEGIN(COMMENT); num_comments++; }
<COMMENT>[^\*\)\(\n]+            { /* do nothing */ }
<COMMENT>\*                      { }
<COMMENT>\)                      { }
<COMMENT>\(                      { }
<COMMENT>{START_COMMENT}         { num_comments++; }
<COMMENT><<EOF>>                 { cool_yylval.error_msg = "EOF in comment"; BEGIN(0); return (ERROR); }
<INITIAL>{END_COMMENT}           { cool_yylval.error_msg = "Unmatched *)"; return (ERROR); }
<COMMENT>{END_COMMENT}           { num_comments--; if (num_comments == 0) BEGIN (0); }
<INITIAL>{LINE_COMMENT}          { BEGIN (SINGLE_COMMENT); }
<SINGLE_COMMENT>\n               { curr_lineno++; BEGIN (0); }
<SINGLE_COMMENT><<EOF>>          { BEGIN (0); }



 /*
  *  The multiple-character operators.
  */
<INITIAL>{DARROW}        { return (DARROW); }
<INITIAL>{ASSIGN}        { return (ASSIGN); }
<INITIAL>{LE}            { return (LE); }



 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
<INITIAL>(?i:class)        { return (CLASS); }
<INITIAL>(?i:else)         { return (ELSE); }
<INITIAL>(?i:if)           { return (IF); }
<INITIAL>(?i:fi)           { return (FI); }
<INITIAL>(?i:in)           { return (IN); }
<INITIAL>(?i:inherits)     { return (INHERITS); }
<INITIAL>(?i:let)          { return (LET); }
<INITIAL>(?i:loop)         { return (LOOP); }
<INITIAL>(?i:pool)         { return (POOL); }
<INITIAL>(?i:then)         { return (THEN); }
<INITIAL>(?i:while)        { return (WHILE); }
<INITIAL>(?i:case)         { return (CASE); }
<INITIAL>(?i:esac)         { return (ESAC); }
<INITIAL>(?i:of)           { return (OF); }
<INITIAL>(?i:new)          { return (NEW); }
<INITIAL>(?i:isvoid)       { return (ISVOID); }
<INITIAL>(?i:not)          { return (NOT); }
<INITIAL>t(?i:rue)         { cool_yylval.boolean = true; return (BOOL_CONST); }
<INITIAL>f(?i:alse)        { cool_yylval.boolean = false; return (BOOL_CONST); }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
<INITIAL>\"                { BEGIN(STRING); string_buf_ptr = string_buf; in_string = true; }
<STRING>[^\\\"\n\0]+       { memcpy(string_buf_ptr, yytext, yyleng); string_buf_ptr += yyleng; }
<STRING>{NEWLINE}          { curr_lineno++; BEGIN(0); if(in_string) { cool_yylval.error_msg = "Unterminated string constant"; in_string = false; return (ERROR);}}
<STRING>\\\0               { cool_yylval.error_msg = "String contains escaped null character"; in_string = false; return (ERROR); }
<STRING>\0                 { cool_yylval.error_msg = "String contains null character"; in_string = false; return (ERROR); }
<STRING><<EOF>>            { cool_yylval.error_msg = "String contains EOF character"; BEGIN(0); return (ERROR); }
<STRING>\\{NEWLINE}        { memcpy(string_buf_ptr++, "\n\0", 2); curr_lineno++; }
<STRING>\\n                { memcpy(string_buf_ptr++, "\n\0", 2); }
<STRING>\\t                { memcpy(string_buf_ptr++, "\t\0", 2); }
<STRING>\\b                { memcpy(string_buf_ptr++, "\b\0", 2); }
<STRING>\\f                { memcpy(string_buf_ptr++, "\f\0", 2); }
<STRING>\\[^\0]            { memcpy(string_buf_ptr++, (const void*)(yytext+1), 1); }

<STRING>\"                 {
                              BEGIN (0);
                              if(in_string) {

                                if (string_buf_ptr - string_buf + 1 > MAX_STR_CONST) {
                                  cool_yylval.error_msg = "String constant too long";
                                  in_string = false;
                                  return (ERROR);
                                } else {
                                  *string_buf_ptr = 0;
                                  cool_yylval.symbol = stringtable.add_string(string_buf);
                                  in_string = false;
                                  return (STR_CONST);
                                }
                              }
                            }

 /* numbers */
<INITIAL>[0-9]+           { cool_yylval.symbol = inttable.add_string(yytext); return (INT_CONST); }



 /* Symbol identifiers */
<INITIAL>[A-Z][a-zA-Z0-9_]*    { cool_yylval.symbol = idtable.add_string(yytext); return (TYPEID); }
<INITIAL>[a-z][a-zA-Z0-9_]*    { cool_yylval.symbol = idtable.add_string(yytext); return (OBJECTID); }

 /* whitespace */
<INITIAL>[\f\r\t\v ]+          { /* ignore whitespace */ }
{NEWLINE}                      { curr_lineno++; }

 /* These are any other single-character lexemes that are valid. They return their ASCII code */
<INITIAL>[\.;:\+/\*\-\(\)@~<=\{\},]  { return ((char)yytext[0]); }

 /* anything else is an error */
<INITIAL>[^\.;:\+\/\*\-\(\)@~<=\{\},a-zA-Z0-9_\s]             { cool_yylval.error_msg = yytext; return (ERROR); }
<INITIAL>_  { cool_yylval.error_msg = "_"; return (ERROR); }

%%
