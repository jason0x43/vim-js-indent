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

" Setup: {{{

" Only load one indent script per buffer
if exists('b:did_indent')
	finish
endif
let b:did_indent = 1

" Set the global log variable 1 = logging enabled, 0 = logging disabled
if !exists("g:js_indent_log")
	let g:js_indent_log = 0
endif

setlocal indentexpr=GetJsIndent(v:lnum)
setlocal indentkeys=],),}

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
	call cursor(a:lnum, 0)

	" Search for the opening tag
	let mnum = searchpair(a:beg, '', a:end, 'bW', 
				\ 'synIDattr(synID(line("."), col("."), 0), "name") =~? s:syn_comment' )

	"Restore the cursor position
	call cursor(curpos)
	
	return mnum
endfunction
" }}}

" GetJsIndent {{{
function! GetJsIndent(lnum)
	" Grab the number of the first non-comment line prior to lnum
	let pnum = s:GetNonCommentLine(a:lnum-1)

	" First line, start at indent = 0
	if pnum == 0
		return 0
	endif

	" Grab the prior prior non-comment line number
	let ppnum = s:GetNonCommentLine(pnum-1)

	let line = getline(a:lnum)
	let pline = getline(pnum)
	let ppline = getline(ppnum)

	" Determine the current level of indentation
	let ind = indent(pnum)

	" Object Closer (closing brace) {{{
	if s:IsObjectEnd(line) && !s:IsComment(a:lnum)
		let beg = s:GetObjectBeg(a:lnum)
		return indent(beg)
	endif

	if s:IsObjectBeg(pline) 
		return ind + &sw 
	endif
	" }}}

	" Array Closer (closing square bracket) {{{
	if s:IsArrayEnd(line) && !s:IsComment(a:lnum)
		let beg = s:GetArrayBeg(a:lnum)
		return indent(beg)
	endif

	if s:IsArrayBeg(pline) 
		return ind + &sw 
	endif
	" }}}

	" Parens {{{
	if s:IsParenEnd(line) && !s:IsComment(a:lnum)
		let beg = s:GetParenBeg(a:lnum)
		return indent(beg)
	endif

	if s:IsParenBeg(pline) 
		return ind + &sw 
	endif
	"}}}

	" Continuation lines {{{
	if s:IsContinuationLine(pline) 
		let beg = s:GetContinuationBegin(pnum)
		return indent(beg) + &sw
	endif

	if s:IsContinuationLine(ppline)
		return ind - &sw
	endif
	"}}}

	" Switch blocks {{{
	if s:IsSwitchMid(pline) 
		if s:IsSwitchMid(line) || s:IsObjectEnd(line)
			return ind
		else
			return ind + &sw
		endif 
	endif

	if s:IsSwitchMid(line)
		return ind - &sw
	endif
	"}}}
	
	" Single Line Control Blocks {{{
	if s:IsControlBeg(pline)
		if s:IsControlMid(line) || line =~ '^\s*{\s*$'
			return ind
		else
			return ind + &sw
		endif
	endif

	if s:IsControlMid(pline)
		if s:IsControlMid(line) || s:IsObjectBeg(line)
			return ind
		else
			return ind + &sw
		endif
	endif

	if s:IsControlMid(line)
		if s:IsControlEnd(pline) || s:IsObjectEnd(pline)
			return ind
		else
			return ind - &sw
		endif
	endif

	if (s:IsControlBeg(ppline) || s:IsControlMid(ppline)) &&
			\ !s:IsObjectBeg(pline) && !s:IsObjectEnd(pline)
		return ind - &sw
	endif
	"}}}

	" no match
	return ind
endfunction
" }}}

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

" }}}

" vim:set fdm=marker fdl=0 ts=4:
