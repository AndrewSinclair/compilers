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
SINGLE_COMMENT  --.*\n

%START          COMMENT STRING

%%

 /*
  *  Nested comments
  */
{START_COMMENT}         { BEGIN(COMMENT); }
<COMMENT>[^\*\)\n<<EOF>>]+     { /* do nothing */ }
<COMMENT>\*             { }
<COMMENT>\)             { }
<COMMENT><<EOF>>        { cool_yylval.error_msg = "EOF in comment"; BEGIN(0); return (ERROR); }
<INITIAL>{END_COMMENT}  { cool_yylval.error_msg = "Unmatched *)"; return (ERROR); }
<COMMENT>{END_COMMENT}           { BEGIN (0); }
{SINGLE_COMMENT}        { curr_lineno++; }


 /*
  *  The multiple-character operators.
  */
{DARROW}        { return (DARROW); }
{ASSIGN}        { return (ASSIGN); }
{LE}            { return (LE); }



 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)        { return (CLASS); }
(?i:else)         { return (ELSE); }
(?i:if)           { return (IF); }
(?i:fi)           { return (FI); }
(?i:in)           { return (IN); }
(?i:inherits)     { return (INHERITS); }
(?i:let)          { return (LET); }
(?i:loop)         { return (LOOP); }
(?i:pool)         { return (POOL); }
(?i:then)         { return (THEN); }
(?i:while)        { return (WHILE); }
(?i:case)         { return (CASE); }
(?i:esac)         { return (ESAC); }
(?i:of)           { return (OF); }
(?i:new)          { return (NEW); }
(?i:isvoid)       { return (ISVOID); }
(?i:not)          { return (NOT); }
t(?i:rue)         { cool_yylval.boolean = true; return (BOOL_CONST); }
f(?i:alse)        { cool_yylval.boolean = false; return (BOOL_CONST); }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
<INITIAL>\"                { BEGIN(STRING); string_buf_ptr = string_buf;}
<STRING>[^\\\"\n\0<<EOF>>]+       { memcpy(string_buf_ptr, yytext, yyleng); string_buf_ptr += yyleng; }
<STRING>{NEWLINE}          { cool_yylval.error_msg = "Unterminated string constant"; BEGIN (0); curr_lineno++; return (ERROR);}
<STRING>\0                 { cool_yylval.error_msg = "String contains null character"; return (ERROR); }
<STRING><<EOF>>            { cool_yylval.error_msg = "String contains EOF character"; BEGIN(0); return (ERROR); }
<STRING>\\{NEWLINE}        { curr_lineno++; }
<STRING>\\n                { memcpy(string_buf_ptr++, "\n", 1); }
<STRING>\\t                { memcpy(string_buf_ptr++, "\t", 1); }
<STRING>\\b                { memcpy(string_buf_ptr++, "\b", 1); }
<STRING>\\f                { memcpy(string_buf_ptr++, "\f", 1); }
<STRING>\\.                { memcpy(string_buf_ptr++, (const void*)(yytext+1), 1); }

<STRING>\"                 { BEGIN (0); cool_yylval.symbol = stringtable.add_string(string_buf); return (STR_CONST); }

 /* numbers */
[0-9]+           { cool_yylval.symbol = inttable.add_string(yytext); return (INT_CONST); }



 /* Symbol identifiers */
[A-Z][a-zA-Z0-9_]*    { cool_yylval.symbol = idtable.add_string(yytext); return (TYPEID); }
[a-z][a-zA-Z0-9_]*    { cool_yylval.symbol = idtable.add_string(yytext); return (OBJECTID); }

 /* whitespace */
[\f\r\t\v ]+          { /* ignore whitespace */ }
{NEWLINE}             { curr_lineno++; }

 /* These are any other single-character lexemes that are valid. They return their ASCII code */
<INITIAL>[\.;:\+/\*\-\(\)@~<=\{\},]  { return ((char)yytext[0]); }

 /* anything else is an error */
<INITIAL>[^\.;:\+\/\*\-\(\)@~<=\{\},a-zA-Z0-9_>\s]             { cool_yylval.error_msg = yytext; return (ERROR); }


%%
