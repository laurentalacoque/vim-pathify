" Test suite for pathify
" Install https://github.com/laurentalacoque/vim-unittest (fixed version of 
" https://github.com/h1mesuke/vim-unittest)
" Run :UnitTest <this file> or <vim-unittest>/bin/vunit <thisfile>
"
" where are we?
let s:here= expand('<sfile>:p:h')
" tests fakeroot
let s:ROOT = s:here."/fakepath"


"--------------------------------------------------------------------------------
" Testcase
"--------------------------------------------------------------------------------
let s:tc = unittest#testcase#new("Test Pathify", {'data' : s:here . '/ressources/test_file.sh'})

"--------------------------------------------------------------------------------
" Setup and Teardown
"--------------------------------------------------------------------------------
" {{{ 1

""" Once SETUP
function! s:tc.SETUP()
    " define markers for data accessors
    call self.puts("Setting marker format")
    let self.data.marker_formats = ['# begin %s', '# end %s']
endfunction

""" every test setup
function! s:tc.setup()
    let s:environ = copy(environ())
    for env in keys(environ())
        execute "unlet $".env
    endfor
    " add fakepath root
    let $ROOT= s:ROOT
    " force pathify to reload its environment
    let g:pathify_reload_environment=1
endfunction

""" every test teardown
function! s:tc.teardown()
    for env in keys(s:environ)
        execute "let $".env ."='".s:environ[env]."'"
    endfor
endfunction

""" prepare test
function! s:tc.substitute_path_root()
    silent! execute "%s/@@/".escape(s:ROOT,"/") ."/g"
endfunction
" }}}

""" test functions


"--------------------------------------------------------------------------------
" Autotest
"--------------------------------------------------------------------------------
" {{{ 1
function! s:tc.test_autotest()
    call self.assert_equal(1,len(keys(environ())),"Setup failed to remove env vars")
    call self.assert_has_key("ROOT",environ())
    let $FOOBAR = 'foobar'
    call self.assert_equal(2,len(keys(environ())),"Bad number of environ vars")
    try
        call self.assert_equal('foobar',environ().FOOBAR,"Bad value for environ var")
    catch "E716"
        call self.fail("Failed to create environ var")
    endtry
endfunction
" }}}

"--------------------------------------------------------------------------------
" Substitution tests
"--------------------------------------------------------------------------------
" {{{ 1

function! s:tc.test_proj1_substitution()
    let $PROJ1 = s:ROOT."/projects/proj1"
    let expected = [
            \ 'setenv MODULE1 = "$PROJ1/module1"',
            \ 'setenv MODULE1INC = "$PROJ1/module1/include/"',
            \ 'setenv MODULE2 = "$PROJ1/module2"',
            \ 'setenv PROJ2SRC = "$ROOT/projects/proj2/proj2.c"',
            \]

    call self.data.goto('test')
    call self.substitute_path_root()

    call pathify#Envify('')
    let result = self.data.get('test')
    for i in range(len(result))
        call self.assert_equal(expected[i], result[i], "Invalid substitution")
    endfor
endfunction

function! s:tc.test_projects_substitution()
    let $PROJECTS = s:ROOT."/projects"
    let expected = [
            \ 'setenv MODULE1 = "$PROJECTS/proj1/module1"',
            \ 'setenv MODULE1INC = "$PROJECTS/proj1/module1/include/"',
            \ 'setenv MODULE2 = "$PROJECTS/proj1/module2"',
            \ 'setenv PROJ2SRC = "$PROJECTS/proj2/proj2.c"',
            \]

    call self.data.goto('test')
    call self.substitute_path_root()

    call pathify#Envify('')
    let result = self.data.get('test')
    for i in range(len(result))
        call self.assert_equal(expected[i], result[i], "Invalid substitution")
    endfor
endfunction

function! s:tc.test_proj1_projects_substitution()
    let $PROJECTS = s:ROOT."/projects"
    let $PROJ1    = s:ROOT."/projects/proj1"
    let expected = [
            \ 'setenv MODULE1 = "$PROJ1/module1"',
            \ 'setenv MODULE1INC = "$PROJ1/module1/include/"',
            \ 'setenv MODULE2 = "$PROJ1/module2"',
            \ 'setenv PROJ2SRC = "$PROJECTS/proj2/proj2.c"',
            \]

    call self.data.goto('test')
    call self.substitute_path_root()

    call pathify#Envify('')
    let result = self.data.get('test')
    for i in range(len(result))
        call self.assert_equal(expected[i], result[i], "Invalid substitution")
    endfor
endfunction

function! s:tc.test_inc_projects_substitution()
    let $PROJECTS = s:ROOT."/projects"
    let $INCDIR = s:ROOT."/projects/proj1/module1/include"
    let expected = [
            \ 'setenv MODULE1 = "$PROJECTS/proj1/module1"',
            \ 'setenv MODULE1INC = "$INCDIR/"',
            \ 'setenv MODULE2 = "$PROJECTS/proj1/module2"',
            \ 'setenv PROJ2SRC = "$PROJECTS/proj2/proj2.c"',
            \]

    call self.data.goto('test')
    call self.substitute_path_root()

    call pathify#Envify('')
    let result = self.data.get('test')
    for i in range(len(result))
        call self.assert_equal(expected[i], result[i], "Invalid substitution")
    endfor
endfunction

function! s:tc.test_substitute_recursive()
    let $PROJECTS = s:ROOT."/projects"
    let $MODULE1 = s:ROOT."/projects/module1"
    let $MODULE1INC = s:ROOT."/projects/proj1/module1/include"
    let expected = [
                \ 'setenv MODULE1 = "$PROJECTS/proj1/module1"',
                \ 'setenv MODULE1INC = "$MODULE1/include/"',
                \ 'setenv HEADER = "$MODULE1INC/module1.h"',
            \]

    call self.data.goto('test2')
    call self.substitute_path_root()

    call pathify#Envify('')
    let result = self.data.get('test2')
    let message = "Invalid substitution"
    for i in range(len(result))
        if i == 2
            let message = "Failed recursive substitution"
        endif
        call self.assert_equal(expected[i], result[i], message)
    endfor
endfunction
" }}}

" vim: :fdm=marker
