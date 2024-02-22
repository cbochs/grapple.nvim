if exists("b:current_syntax")
  finish
endif

syn match GrappleId /^\/\d* / conceal

let b:current_syntax = "grapple"
