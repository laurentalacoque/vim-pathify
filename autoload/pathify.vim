" SCRIPT VARIABLES {{{
" s:ENV2PATH is a dictionnary that contain all environment variables (keys) that contain a directory (value)
let s:ENV2PATH = {}
let s:ENV2PATH_sorted_keys = [] "keys of ENV2PATH sorted by value length
" s:ENV2FILE is a dictionnary that contain all environment variables (keys) that contain a file (value)
let s:ENV2FILE = {}
"}}}

" initialization from environment
function! s:INIT() abort
    "{{{
    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " Handle PATH
    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " prefilter: must contain '/'
    let subset        = filter(environ(), 'v:val =~# "\/"')
    " filter: must be a directory
    let s:ENV2PATH = filter(subset,'isdirectory(expand(v:val))')
    let s:ENV2PATH_sorted_keys = sort(keys(s:ENV2PATH),function('s:sort_by_path_length'))


    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " Handle FILES
    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " prefilter: must look like a file
    let subset         = filter(environ(), 'v:val =~# "^[a-zA-Z0-9_. ~/-]\\+$"')
    " filter: must be a readable file
    let s:ENV2FILE = filter(subset, 'filereadable(expand(v:val))')

" }}}
endfunction

function! pathify#Envify(flags='c') abort
"{{{
    " should we reload environment ?
    if exists('g:pathify_reload_environment')
        echom "pathify: reloading environment..."
        call s:INIT()
        echom "pathify: " .. len(keys(s:ENV2PATH)) .. " environment vars containing path"
        echom "pathify: environ(): " . string(environ())

        unlet g:pathify_reload_environment
    endif

    " find substitutions
    for envkey in s:ENV2PATH_sorted_keys
        " escape path
        let fullpath = escape(fnameescape(expand(s:ENV2PATH[envkey])),'/')
        " by what we will substitute
        "TODO can depend on the language
        " ${ENV} / $ENV / $env(ENV) / ...
        let substitution = '$'.envkey
        let substitution = escape(substitution,'/')

        " check if there's something to find
        if search(fullpath,'cw')
            " there is, run a real substitution with confirmation
            execute ":%s/".fullpath."/".substitution."/".a:flags
        endif
    endfor

    for envkey in keys(s:ENV2FILE)
        let fullpath = escape(fnameescape(expand(s:ENV2FILE[envkey])),'/')
        "TODO can depend on the language
        " ${ENV} / $ENV / $env(ENV) / ...
        let substitution = '$'.envkey
        let substitution = escape(substitution,'/')
        if search(fullpath,'c')
            execute ":%s/".fullpath."/".substitution."/".a:flags
        endif
    endfor
" }}}
endfunction


"}}}

" Helper Functions {{{
function! s:sort_by_path_length(item1,item2) abort
    if len(s:ENV2PATH[a:item1]) > len(s:ENV2PATH[a:item2])
        return -1 "larger first
    elseif len(s:ENV2PATH[a:item1]) < len(s:ENV2PATH[a:item2])
        return 1  "smaller second
    else
        return 0
    endif
endfunction
" }}}

" Init
call s:INIT()

"vim: fdm=marker
