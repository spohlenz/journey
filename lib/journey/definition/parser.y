class Journey::Definition::Parser

token SLASH LITERAL SYMBOL LPAREN RPAREN DOT STAR

rule
  path
    : paths              { result = Node.new(:PATH, val.flatten) }
    | SLASH              { result = Node.new(:PATH, Node.new(:SLASH, [])) }
    ;
  paths
    : segment paths      { result = val.flatten }
    | group paths        { result = val.flatten }
    | dot paths          { result = val.flatten }
    | segment
    | group
    | dot
    | star
    ;
  segment
    : SLASH literal      { result = Node.new(:SLASH, [val.last]) }
    | SLASH symbol       { result = Node.new(:SLASH, [val.last]) }
    | SLASH star         { result = Node.new(:SLASH, [val.last]) }
    | SLASH group        { result = Node.new(:SLASH, [val.last]) }
    ;
  dot
    : DOT symbol         { result = Node.new(:DOT, [val.last]) }
    | DOT literal        { result = Node.new(:DOT, [val.last]) }
    ;
  group
    : LPAREN paths RPAREN { result = Node.new(:GROUP, [val[1]].flatten) }
    | LPAREN symbol RPAREN { result = Node.new(:GROUP, [val[1]]) }
    ;
  symbol
    : SYMBOL             { result = Node.new(:SYMBOL, val.first) }
    ;
  literal
    : LITERAL            { result = Node.new(:LITERAL, val.first) }
  star
    : STAR LITERAL       { result = Node.new(:STAR, val.last) }
    ;

end

---- header

require 'journey/definition/parser_extras'
