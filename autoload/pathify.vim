" Bailout when we're below 8.2
if (v:version < 802)
    echohl ErrorMsg
    echo "Pathify needs vim > 8.2, bailing out"
    echohl None
    finish
endif

" SCRIPT VARIABLES {{{
" s:ENV2PATH is a dictionnary that contain all environment variables (keys) that contain a directory (value)
let s:ENV2PATH = {}
let s:ENV2PATH_sorted_keys = [] "keys of ENV2PATH sorted by value length
" s:ENV2FILE is a dictionnary that contain all environment variables (keys) that contain a file (value)
let s:ENV2FILE = {}

let s:valid_chars_in_path = '[a-zA-Z0-9_ ~.@$\/-]'
let s:path_pattern = '\('.. s:valid_chars_in_path .. '*\/' .. s:valid_chars_in_path .. '\+\)'
" those are used to escape() in search and substitutions
let s:pattern_escape_list = '/$~.'
let s:substitution_escape_list = '&/$~'

let s:valid_chars_in_env = '[a-zA-Z0-9.@_-]'


"}}}

" initialization from environment
function! s:INIT() abort
    "{{{
    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " Handle PATH
    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " prefilter: must contain '/'
    let subset        = filter(environ(), 'v:val =~# "'.. s:valid_chars_in_path ..'"')
    let subset['CWD'] = getcwd()
    " filter: must be a directory
    " TODO some environment variables can be simple directory names
    " TODO such as 'subpath' and still be used in other paths
    " TODO example /path/to/$SUBPATH/fullpath
    " TODO 'isdirectory' here might be too restrictive but expand() works with the full environment
    " TODO so... there's that.
    let s:ENV2PATH = filter(subset,'isdirectory(expand(v:val))')
    let s:ENV2PATH_sorted_keys = sort(keys(s:ENV2PATH),function('s:sort_by_path_length'))


    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " Handle FILES
    """""""""""""""""""""""""""""""""""""""""""""""""""""
    " prefilter: must look like a file
    let subset         = filter(environ(), 'v:val =~# "^'.. s:valid_chars_in_path..'\+$"')
    " filter: must be a readable file
    let s:ENV2FILE = filter(subset, 'filereadable(expand(v:val))')

" }}}
endfunction

function! pathify#Envify(flags='c') abort
"{{{
    " should we reload environment ?
    if exists('g:pathify_reload_environment')
        call s:INIT()
        unlet g:pathify_reload_environment
    endif


    let buffer_paths = s:get_buffer_paths()

    " handle confirmation ('c' flag)
    let confirm = 0
    if a:flags =~# 'c'
        let confirm = 1
    endif

    for item in buffer_paths

        if confirm
            " confirm all subsitutions: prompt for change
            let result = s:substitute_with_prompt(item.line, item.path, item.factorized)
            " check answer
            if result == 0
                "quit selected
                return
            elseif result == 2
                "always selected: unset confirm
                let confirm = 0
            endif
        else
            " no confirmation needed
            let line = getline(item.line)
            let line = substitute(line,
                        \ escape(item.path,s:pattern_escape_list),
                        \ escape(item.factorized,s:substitution_escape_list),
                        \ a:flags)
            "substitute line in buffer
            call setline(item.line,line)
        endif

    endfor

" }}}
endfunction

function! pathify#Pathify(flags='c') abort
"{{{
    " should we reload environment ?
    if exists('g:pathify_reload_environment')
        call s:INIT()
        unlet g:pathify_reload_environment
    endif


    let buffer_paths = s:get_buffer_paths()

    " handle confirmation ('c' flag)
    let confirm = 0
    if a:flags =~# 'c'
        let confirm = 1
    endif

    for item in buffer_paths

        if confirm
            " confirm all subsitutions: prompt for change
            let result = s:substitute_with_prompt(item.line, item.path, item.expanded)
            " check answer
            if result == 0
                "quit selected
                return
            elseif result == 2
                "always selected: unset confirm
                let confirm = 0
            endif
        else
            " no confirmation needed
            let line = getline(item.line)
            let line = substitute(line,
                        \ escape(item.path,s:pattern_escape_list),
                        \ escape(item.expanded,s:substitution_escape_list),
                        \ a:flags)
            "substitute line in buffer
            call setline(item.line,line)
        endif

    endfor

" }}}
endfunction

" search for the invalid paths in file
function! pathify#CheckPath(clear=0)
    " clear highlights
    call clearmatches()
    if a:clear
        return
    endif

    "" check for invalid path
    let b:pathify_invalid_paths = filter(s:get_buffer_paths(), 'v:val["isvalid"] == 0')

    let first_error_line = 0
    for item in b:pathify_invalid_paths
        if !first_error_line
            let first_error_line = item.line
        endif
        "highlight search but only on the current line '\%23l<pattern>'
        call matchadd('PathifyUnkPath','\%'.. item.line .."l".escape(item.path,s:pattern_escape_list))
    endfor
    "move to first error
    call cursor(first_error_line, 1)
endfunction

" search for the invalid paths in file
function! pathify#CheckEnv(clear=0)
    " clear highlights
    call clearmatches()
    if a:clear
        return
    endif

    "" check for invalid env
    let b:pathify_invalid_envs = filter(s:get_buffer_envvars(), 'v:val["cansubstitute"] == 0')

    let first_error_line = 0
    for item in b:pathify_invalid_envs
        if !first_error_line
            let first_error_line = item.line
        endif

        " By default highlight with unknown env
        let highlight_group = 'PathifyUnkEnv'
        if item.inenviron
            " item in environment but not in ENV2PATH / ENV2FILE
            " highlight using class PathifyNotPathEnv
            let highlight_group = 'PathifyNotPathEnv'
        endif

        "highlight search but only on the current line '\%23l<pattern>'
        call matchadd(highlight_group,'\%'.. item.line .."l".escape(item.env,s:pattern_escape_list))
    endfor
    "move to first error
    call cursor(first_error_line, 1)
endfunction



" Helper Functions {{{
function! s:get_buffer_paths() abort
    " should we reload environment ?
    if exists('g:pathify_reload_environment')
        call s:INIT()
        echom "pathify: reloading environment: " .. len(keys(s:ENV2PATH)) .. " environment vars containing path"
        unlet g:pathify_reload_environment
    endif

    " create a dict formed from s:ENV2PATH + s:ENV2FILE
    let env = deepcopy(s:ENV2PATH)
    call extend(env, s:ENV2FILE)
    let env_keys_sorted = deepcopy(s:ENV2PATH_sorted_keys)
    call extend(env_keys_sorted, keys(s:ENV2FILE))

    " initialize return value
    let all_path = []

    " remember cursor position
    let cursorpos = getcurpos()[1:]

    " find all path in current buffer
    normal! 1G
    let line = search(s:path_pattern,'cW')
    while line !=0
        let item = #{line : line}
        let curline = getline(line)

        let path = matchlist(curline, s:path_pattern)
        if !empty(path)
            let item.path = path[1]

            """" item.expanded : longest path
            " replace ./ by $CWD/ for substitution
            let item.expanded = substitute(item.path,'^\.\/',s:ENV2PATH['CWD'] .. '\/','')
            let item.expanded = expand(item.expanded)

            """ now that we have the expanded path, check if it is a valid directory or file
            let item.isfile = filereadable(item.expanded)
            let item.isdir  = isdirectory(item.expanded)
            let item.isvalid = item.isfile || item.isdir

            """ item.factorized : most environment variables
            " initialize factorized
            let item.factorized = item.expanded

            " substitute every possible ENV value starting with the largest one
            for envkey in env_keys_sorted
                let fullpath = escape(
                            \ fnameescape(expand(env[envkey])),
                            \ s:pattern_escape_list)
                " by what we will substitute
                if envkey ==# "HOME"
                    let substitution = '~'
                elseif envkey ==# "CWD"
                    let substitution = '.'
                else
                    "TODO can depend on the language
                    " ${ENV} / $ENV / $env(ENV) / ...
                    let substitution = '$'.envkey
                endif

                let substitution = escape(substitution,s:substitution_escape_list)

                "don't substitute when the path is preceded by the same environment variable
                "This is to avoid to have autorefs like 'setenv HOME = $HOME
                if curline =~# '\<'.escape(envkey,'/$.~').'\>.\{-\}'.escape(item['path'],'/$.~')
                    "echom "skiping '".envkey."' subsitution for: '". curline ."'"
                    continue
                else
                    let item.factorized = substitute(item.factorized, fullpath, substitution,'g')
                endif
            endfor

            let all_path += [item]
        endif

        "next occurence
        "move to end of line to avoid matching again on the same line
        normal! $
        let line = search('\/','W')
    endwhile

    "restore cursor position
    call cursor(cursorpos)
    " return path
    return all_path
endfunction

function! s:get_buffer_envvars() abort
    let find_env_pat = s:get_envref_patterns()
    let all_env = []

    "echom "patterns: " .. string(find_env_pat)
    " remember cursor position
    let cursorpos = getcurpos()[1:]

    " find all environment variables in current buffer
    normal! 1G
    " search throughout the buffer
    let line = search(find_env_pat,'cW')
    while line !=0
        " found a match
        let item = #{line : line}
        let curline = getline(line)

        let env = matchlist(curline, find_env_pat)
        if !empty(env)
            let item.env = env[1]
            let item.inenviron = exists('$'.item.env)
            let item.inpath = has_key(s:ENV2PATH,item.env)
            let item.infile = has_key(s:ENV2FILE,item.env)
            let item.cansubstitute = item.inpath || item.infile
            let all_env += [item]
        endif

        "next occurence, move to end of line to avoid multiple matches
        normal! $
        let line = search('\/','W')
    endwhile

    "restore cursor position
    call cursor(cursorpos)
    " return env
    return all_env

    
endfunction

" highlight search on the current line and prompt for substitution
function! s:substitute_with_prompt(line,search,substitution)
    " remember cursor position
    let cursorpos = getcurpos()[1:]

    "goto line
    call cursor(a:line,1)
    let l:curline = getline(a:line)

    "highlight search but only on the current line '\%23l<pattern>'
    execute 'match Search /\%'.. a:line .."l".escape(a:search,s:pattern_escape_list)."/"
    redraw

    " ask for permission
    echohl Question
    let l:prompt = input("replace with '".. a:substitution .. "'? [Y,a,n,q]: ",'')
    echohl None

    " clear l:prompt highlight
    match

    " decide what to do
    if len(l:prompt) == 0 || l:prompt ==? "y" || l:prompt ==? "a"

        let l:curline = substitute(l:curline,
                    \ escape(a:search,s:pattern_escape_list),
                    \ escape(a:substitution,s:substitution_escape_list),'')
        "substitute line in buffer
        call setline(a:line,l:curline)

    elseif l:prompt ==? "q"
        call cursor(cursorpos)
        " no more please
        return 0
    endif

    " restore position
    call cursor(cursorpos)

    if l:prompt ==? "a"
        "please don't ask again
        return 2
    else
        " keep going
        return 1
    endif

endfunction

function! s:sort_by_path_length(item1,item2) abort
    if len(s:ENV2PATH[a:item1]) > len(s:ENV2PATH[a:item2])
        return -1 "larger first
    elseif len(s:ENV2PATH[a:item1]) < len(s:ENV2PATH[a:item2])
        return 1  "smaller second
    else
        return 0
    endif
endfunction

" helper function that builds a search pattern
" from a list of valid forms ['$#'] means env vars
" are referenced like $ENVVAR. ['$#','${#}'] means
" $ENVVAR and ${ENVVAR} are both valid
function! s:get_envref_patterns(forms = ['$#', '${#}', '$env(#)']) abort
    let forms = a:forms
    "TODO replace with b:pathify_envref_forms if it exists?
    "
    " build escaped env reference pattern list
    let envref_pattern_list = []
    for form in forms
        " substitute '#' with \(ENV\)
        let pattern = substitute(
                    \ escape(form,s:pattern_escape_list),
                    \ '#', 
                    \ '\\('.s:valid_chars_in_env.'\\+\\)','')
        let envref_pattern_list += [pattern]
    endfor
    return join(envref_pattern_list,'\|')
endfunction
" }}}

" Init
call s:INIT()

" DEBUG {{{
function! pathify#DBG_get_environment()

    echohl WarningMsg
    echom "ENV2PATH"
    echohl None
    for key in s:ENV2PATH_sorted_keys
        echom "    ".key." : ".s:ENV2PATH[key]
    endfor
    echom ""
    echohl WarningMsg
    echom "ENV2FILE"
    echohl None
    for key in keys(s:ENV2FILE)
        echom "    ".key." : ".s:ENV2FILE[key]
    endfor
    echom ""
    let buffer_paths = s:get_buffer_paths()
    echohl WarningMsg
    echom "buffer_paths"
    echohl None
    for item in buffer_paths
        echom "    ". item['path'] . " (". item['line'].")"
        echom "          expanded: " . item['expanded']
        echom "        factorized: " . item['factorized']
        echom "           isvalid: "    .. item.isvalid ..
                    \ "    isfile: " .. item.isfile..
                    \ "    isdir: "  .. item.isdir
    endfor
    return #{ENV2PATH : s:ENV2PATH, ENV2FILE: s:ENV2FILE, ENV2PATH_sorted_keys: s:ENV2PATH_sorted_keys}
endfunction
"}}}

" Color highlights {{{
highlight default PathifyUnkPath    term=standout cterm=bold ctermfg=7 ctermbg=1 guifg=White guibg=OrangeRed
highlight default PathifyUnkEnv     term=standout cterm=bold ctermfg=7 ctermbg=1 guifg=black guibg=OrangeRed
highlight default PathifyNotPathEnv term=standout cterm=bold ctermfg=7 ctermbg=1 guifg=black guibg=gold
"}}}

" vim: :fdm=marker
