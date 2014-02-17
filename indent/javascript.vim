" Vim indent script for JavaScript
" General:
" File:			javascript.vim
" Maintainer:	Jason Cheatham
" Last Change: 	2014-02-15
" Description:
" 	JavaScript indenter.
"
" Credits:
"	javascript.vim (2011 May 15) from Preston Koprivica

" Options: {{{

" set to 1 to make case statements align with the containing switch
if !exists('g:js_indent_flat_switch')
	let g:js_indent_flat_switch = 0
endif

" set to 1 to make case statements align with the containing switch
if !exists('g:js_indent_logging')
	let g:js_indent_logging = 0
endif

" }}}

" Setup: {{{

" Only load one indent script per buffer
if exists('b:did_indent')
	finish
endif
let b:did_indent = 1

setlocal indentexpr=GetJsIndent(v:lnum)
setlocal indentkeys=0],0),0},:,!^F,o,O,e

setlocal cindent
setlocal autoindent
" }}}

" Variables: {{{

" Inline comments (for anchoring other statements)
let s:js_mid_line_comment = '\s*\(\/\*.*\*\/\)*\s*'
let s:js_end_line_comment = s:js_mid_line_comment . '\s*\(//.*\)*'
let s:js_line_comment = s:js_end_line_comment

" Comment/string syntax key
let s:syn_comment = '\(Comment\|String\|Regexp\)'
" }}}

" Indenter: {{{
function! GetJsIndent(lnum)
	call s:Log('starting indent')

	" Grab the number of the first non-comment line prior to lnum
	let pnum = s:GetNonCommentLine(a:lnum-1)

	" First line, start at indent = 0
	if pnum == 0
		call s:Log('first line -- returning')
		return 0
	endif

	" Grab the prior prior non-comment line number
	let ppnum = s:GetNonCommentLine(pnum-1)

	let line = getline(a:lnum)
	let pline = getline(pnum)
	let ppline = getline(ppnum)

	" Determine the current level of indentation
	let ind = indent(pnum)

	if s:IsVarBlockBegin(pline)
		" start of var block
		call s:Log('var block')
		return ind + &sw
	elseif s:IsSwitchBeginSameLine(pline) && !s:IsObjectEnd(line)
		" switch begin
		s:Log('begin switch')
		return ind + (g:js_indent_flat_switch ? 0 : &sw)
	elseif s:IsObjectEnd(line) && !s:IsComment(a:lnum)
		" object end
		call s:Log('end object')
		return indent(s:GetObjectBeg(a:lnum))
	elseif s:IsObjectBeg(pline) 
		" first line inside object
		call s:Log('begin object')
		return ind + &sw
	elseif s:IsArrayEnd(line) && !s:IsComment(a:lnum)
		" array end
		call s:Log('end array')
		return indent(s:GetArrayBeg(a:lnum))
	elseif s:IsArrayBeg(pline) 
		" first line inside array
		call s:Log('begin array')
		return ind + &sw 
	elseif s:IsParenEnd(line) && !s:IsComment(a:lnum)
		" parenthetical end
		call s:Log('end paren')
		return indent(s:GetParenBeg(a:lnum))
	elseif s:IsParenBeg(pline) 
		" parenthetical begin
		call s:Log('begin paren')
		return ind + &sw 
	elseif s:IsContinuationLine(pline) 
		" first continuation line
		call s:Log('continuation')
		return indent(s:GetContinuationBegin(pnum)) + &sw
	elseif s:IsContinuationLine(ppline)
		" second continuation line
		call s:Log('prior-prior continuation')
		return ind - &sw
	elseif s:IsSwitchMid(pline) && !(s:IsSwitchMid(line) || s:IsObjectEnd(line))
		" first line in case block
		call s:Log('in switch mid')
		return ind + &sw
	elseif s:IsSwitchMid(line)
		" case label
		call s:Log('case label')
		return ind - &sw
	elseif s:IsControlBeg(pline) && !(s:IsControlMid(line) || line =~ '^\s*{\s*$')
		" control statements
		call s:Log('control beg')
		return ind + &sw
	elseif s:IsControlMid(pline) && !(s:IsControlMid(line) || s:IsObjectBeg(line))
		call s:Log('prior control mid')
		return ind + &sw
	elseif s:IsControlMid(line) && !(s:IsControlEnd(pline) || s:IsObjectEnd(pline))
		call s:Log('control mid')
		return ind - &sw
	elseif (s:IsControlBeg(ppline) || s:IsControlMid(ppline)) &&
			\ !(s:IsObjectBeg(pline) || s:IsObjectEnd(pline))
		call s:Log('prior-prior control beg or mid')
		return ind - &sw
	endif

	call s:Log('no match')
	return ind
endfunction
" }}}

" Auxiliary functions: {{{

" IsInComment {{{
" Determine whether the specified position is contained in a comment.
function! s:IsInComment(lnum, cnum)
	return synIDattr(synID(a:lnum, a:cnum, 1), 'name') =~? s:syn_comment
endfunction'
" }}}

" IsComment {{{
" Determine whether a line is a comment or not.
function! s:IsComment(lnum)
	let line = getline(a:lnum)
	"Doesn't absolutely work.  Only Probably!
	return s:IsInComment(a:lnum, 1) && s:IsInComment(a:lnum, strlen(line))
endfunction
" }}}

" GetNonCommentLine {{{
" Grab the nearest non-commented line.
function! s:GetNonCommentLine(lnum)
	let lnum = prevnonblank(a:lnum)

	while lnum > 0
		if s:IsComment(lnum)
			let lnum = prevnonblank(lnum - 1)
		else
			return lnum
		endif
	endwhile

	return lnum
endfunction
" }}}

" SearchForPair {{{
" Return the beginning tag of a given pair starting from the given line.
function! s:SearchForPair(lnum, beg, end)
	" Save the cursor position
	let curpos = getpos(".")

	" Set the cursor position to the beginning of the line (default
	" behavior when using ==)
	call cursor(a:lnum, 1)

	" Search for the opening tag
	let mnum = searchpair(a:beg, '', a:end, 'bW', 
				\ 'synIDattr(synID(line("."), col("."), 0), "name") =~? s:syn_comment' )

	"Restore the cursor position
	call cursor(curpos)
	
	return mnum
endfunction
" }}}

" Log {{{
function! s:Log(msg)
	if g:js_indent_logging
		echom a:msg
	endif
endfunction
"}}}

" }}}

" Helper functions: {{{

" Object helpers {{{
let s:object_beg = '{[^}]*' . s:js_end_line_comment . '$'
let s:object_end = '^' . s:js_mid_line_comment . '}[;,]\='

function! s:IsObjectBeg(line)
	return a:line =~ s:object_beg
endfunction

function! s:IsObjectEnd(line)
	return a:line =~ s:object_end
endfunction 

function! s:GetObjectBeg(lnum)
	return s:SearchForPair(a:lnum, '{', '}')
endfunction
" }}}

" Array helpers {{{
let s:array_beg = '\[[^\]]*' . s:js_end_line_comment . '$'
let s:array_end = '^' . s:js_mid_line_comment . '[^\[]*\]'

function! s:IsArrayBeg(line)
	return a:line =~ s:array_beg
endfunction

function! s:IsArrayEnd(line)
	return a:line =~ s:array_end
endfunction 

function! s:GetArrayBeg(lnum)
	return s:SearchForPair(a:lnum, '\[', '\]')
endfunction
" }}}

" MultiLine declaration/invocation helpers {{{
let s:paren_beg = '([^)]*' . s:js_end_line_comment . '$'
let s:paren_end = '^' . s:js_mid_line_comment . '[^(]*)'

function! s:IsParenBeg(line)
	return a:line =~ s:paren_beg
endfunction

function! s:IsParenEnd(line)
	return a:line =~ s:paren_end
endfunction 

function! s:GetParenBeg(lnum)
	return s:SearchForPair(a:lnum, '(', ')')
endfunction
" }}}

" Continuation helpers {{{
let s:continuation = '\(+\|\\\)\{1}' . s:js_line_comment . '$' 

function! s:IsContinuationLine(line)
	return a:line =~ s:continuation
endfunction

function! s:GetContinuationBegin(lnum) 
	let cur = a:lnum
	
	while s:IsContinuationLine(getline(cur)) 
		let cur -= 1
	endwhile
	
	return cur + 1
endfunction 
" }}}

" Switch helpers {{{
let s:switch_beg_next_line = 'switch\s*(.*)\s*' . s:js_mid_line_comment . s:js_end_line_comment . '$'
let s:switch_beg_same_line = 'switch\s*(.*)\s*' . s:js_mid_line_comment . '{\s*' . s:js_line_comment . '$'
let s:switch_mid = '^.*\(case.*\|default\)\s*:\s*' 

function! s:IsSwitchBeginNextLine(line) 
	return a:line =~ s:switch_beg_next_line 
endfunction

function! s:IsSwitchBeginSameLine(line) 
	return a:line =~ s:switch_beg_same_line 
endfunction

function! s:IsSwitchMid(line)
	return a:line =~ s:switch_mid
endfunction 
" }}}

" Control helpers {{{
let s:cntrl_beg_keys = '\(\(\(if\|for\|with\|while\)\s*(.*)\)\|\(try\|do\)\)\s*'
let s:cntrl_mid_keys = '\(\(\(else\s*if\|catch\)\s*(.*)\)\|\(finally\|else\)\)\s*'

let s:cntrl_beg = s:cntrl_beg_keys . s:js_end_line_comment . '$' 
let s:cntrl_mid = s:cntrl_mid_keys . s:js_end_line_comment . '$' 

let s:cntrl_end = '\(while\s*(.*)\)\s*;\=\s*' . s:js_end_line_comment . '$'

function! s:IsControlBeg(line)
	return a:line =~ s:cntrl_beg
endfunction

function! s:IsControlMid(line)
	return a:line =~ s:cntrl_mid
endfunction

function! s:IsControlMidStrict(line)
	return a:line =~ s:cntrl_mid
endfunction

function! s:IsControlEnd(line)
	return a:line =~ s:cntrl_end
endfunction
" }}}

" Var block helpers {{{
let s:var_block_beg = '\<var \w\+\>.*,' . s:js_end_line_comment . '$'

function! s:IsVarBlockBegin(line)
	return a:line =~ s:var_block_beg
endfunction
" }}}

" }}}

" vim:set fdm=marker fdl=0 ts=4:
