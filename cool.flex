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

int comment_qiantao = 0;
int string_length = 0;

%}

/*
 * Define names for regular expressions here.
 */

DARROW    =>
ASSIGN    <-
LE        <=

NOTATION  ";"|","|":"|"{"|"}"|"("|")"|"~"|"+"|"-"|"*"|"/"|"."|"@"|"<"|"="


INTCONST  [0-9]+
TYPEID    [A-Z][A-Za-z0-9_]*
OBJECTID  [a-z][A-Za-z0-9_]*

CLASS     (?i:class)
INHERITS  (?i:inherits)
IF        (?i:if)
THEN      (?i:then)
ELSE      (?i:else)
FI        (?i:fi)
WHILE     (?i:while)
LOOP      (?i:loop)
POOL      (?i:pool)
LET       (?i:let)
IN        (?i:in)
CASE      (?i:case)
OF        (?i:of)
ESAC      (?i:esac)
NEW       (?i:new)
ISVOID    (?i:isvoid)
NOT       (?i:not)
TRUE      t(?i:rue)
FALSE     f(?i:alse)

WHITESPACE \ |\f|\r|\t|\v
NEWLINE    \n

COMMENTLINE    --

%x CM
%x STR
%x BADSTR

%%

 /*
  *  Nested comments
  */

{COMMENTLINE}.*{NEWLINE} { curr_lineno++; }
{COMMENTLINE}.*          { curr_lineno++; }


<INITIAL>"(*"            { BEGIN(CM); comment_qiantao++; }
<CM>"(*"                 { comment_qiantao++; }
<INITIAL>"*)"            {
                           cool_yylval.error_msg = "Unmantched *)";
                           return (ERROR);
                         }                       
<CM>"*)"                 {
                           comment_qiantao--;
                           if ( comment_qiantao == 0 ) BEGIN(INITIAL); 
                         }
<CM>{NEWLINE}            { curr_lineno++; }
<CM>.                    {                }
<CM><<EOF>>              {
                           BEGIN(INITIAL);
                           cool_yylval.error_msg = "EOF in comment";
                           return (ERROR);
                         }

 /*
  *  The multiple-character operators.
  */

{DARROW}		{ return (DARROW); }
{ASSIGN}        { return (ASSIGN); }
{LE}            { return (LE);     }

 /*
  *  The single-character operators.
  */

{NOTATION}      { return yytext[0]; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{CLASS}         { return (CLASS);    }
{INHERITS}      { return (INHERITS); }
{IF}            { return (IF);       }
{THEN}          { return (THEN);     }
{ELSE}          { return (ELSE);     }
{FI}            { return (FI);       }
{WHILE}         { return (WHILE);    }
{LOOP}          { return (LOOP);     }
{POOL}          { return (POOL);     }
{LET}           { return (LET);      }
{IN}            { return (IN);       }
{CASE}          { return (CASE);     }
{OF}            { return (OF);       }
{ESAC}          { return (ESAC);     }
{NEW}           { return (NEW);      }
{ISVOID}        { return (ISVOID);   }
{NOT}           { return (NOT);      }
{TRUE}          {
                  cool_yylval.boolean = true; 
                  return (BOOL_CONST);
                }
{FALSE}         {
                  cool_yylval.boolean = false; 
                  return (BOOL_CONST);
                }

 /*
  *  Int constants
  */

{INTCONST} {
             cool_yylval.symbol = inttable.add_string(yytext);
             return (INT_CONST);
           }

 /*
  *  ID constants
  */

{TYPEID}   {
             cool_yylval.symbol = idtable.add_string(yytext);
             return (TYPEID);
           }

{OBJECTID} {
             cool_yylval.symbol = idtable.add_string(yytext);
             return (OBJECTID);
           }

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
<BADSTR>.*[\"\n] { BEGIN(INITIAL); }
\"               { BEGIN(STR);     }
<STR>\"          { cool_yylval.symbol = stringtable.add_string(string_buf);
                   string_length = 0;
                   string_buf[0] = '\0';
                   BEGIN(INITIAL);
                   return (STR_CONST); }
<STR>(\0|\\\0)   { cool_yylval.error_msg = "String contains null character";
                   BEGIN(BADSTR);
                   return (ERROR); }

<STR>\\\n        { if (string_length + 1 >= MAX_STR_CONST) {
                   BEGIN(BADSTR);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "String constant too long";
                   return (ERROR);
                   } else {
                   string_length++;
                   curr_lineno++;
                   strcat(string_buf, "\n"); }
                 }
<STR>\n          { curr_lineno++;
                   BEGIN(INITIAL);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "Unterminated string constant";
                   return (ERROR); }
<STR><<EOF>>     { BEGIN(INITIAL);
                   cool_yylval.error_msg = "EOF in string constant";
                   return (ERROR); }
<STR>\\n         { if (string_length + 1 >= MAX_STR_CONST) {
                   BEGIN(BADSTR);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "String constant too long";
                   return (ERROR);
                   } else {
                   string_length++;
                   // curr_lineno++;
                   strcat(string_buf, "\n"); 
                   }
                 }
<STR>\\t         { if (string_length + 1 >= MAX_STR_CONST) {
                   BEGIN(BADSTR);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "String constant too long";
                   return (ERROR);
                   } else {
                   string_length++;
                   strcat(string_buf, "\t"); 
                   }
                 }
<STR>\\b         { if (string_length + 1 >= MAX_STR_CONST) {
                   BEGIN(BADSTR);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "String constant too long";
                   return (ERROR);
                   } else {
                   string_length++;
                   strcat(string_buf, "\b"); 
                   }
                 }
<STR>\\f         { if (string_length + 1 >= MAX_STR_CONST) {
                   BEGIN(BADSTR);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "String constant too long";
                   return (ERROR);
                   } else {
                   string_length++;
                   strcat(string_buf, "\f"); 
                   }
                 }
<STR>\\.         { if (string_length + 1 >= MAX_STR_CONST) {
                   BEGIN(BADSTR);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "String constant too long";
                   return (ERROR);
                   } else {
                   string_length++;
                   string_buf_ptr = strdup(yytext);
                   strcat(string_buf, &string_buf_ptr[1]); 
                   free(string_buf_ptr);
                   }
                 }
<STR>.           { if (string_length + 1 >= MAX_STR_CONST) {
                   BEGIN(BADSTR);
                   string_length = 0;
                   string_buf[0] = '\0';
                   cool_yylval.error_msg = "String constant too long";
                   return (ERROR);
                   } else {
                   string_length++;
                   strcat(string_buf, yytext); 
                   }
                 }

 /*
  *  OTHERS
  */

{NEWLINE}    { curr_lineno++; }
{WHITESPACE} {                }
.            {
               cool_yylval.error_msg = yytext;
               return (ERROR);
             }

%%