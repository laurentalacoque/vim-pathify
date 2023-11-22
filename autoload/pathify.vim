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
    let subset['CWD'] = getcwd()
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
            let line = substitute(line,escape(item.path,'/$.'),escape(item.factorized,'&~/'),a:flags)
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
            let line = substitute(line,escape(item.path,'/$.'),escape(item.expanded,'&~/'),a:flags)
            "substitute line in buffer
            call setline(item.line,line)
        endif

    endfor

" }}}
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
    let line = search('\/','cW')
    while line !=0
        let item = #{line : line}
        let curline = getline(line)

        let path = matchlist(curline, '\([a-zA-Z0-9_ ~.@$\/-]*\/[a-zA-Z0-9_ ~.@$\/-]\+\)')
        if !empty(path)
            let item.path = path[1]
            " replace ./ by $CWD/ for substitution
            let item.expanded = substitute(item.path,'^\.\/',s:ENV2PATH['CWD'] .. '\/','')
            let item.expanded = expand(item.expanded)

            " initialize factorized
            let item.factorized = item.expanded

            " substitute every possible ENV value starting with the largest one
            for envkey in env_keys_sorted
                let fullpath = escape(fnameescape(expand(env[envkey])),'/$.')
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

                let substitution = escape(substitution,'/$.~')

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


" highlight search on the current line and prompt for substitution
function! s:substitute_with_prompt(line,search,substitution)
    " remember cursor position
    let cursorpos = getcurpos()[1:]

    "goto line
    call cursor(a:line,1)
    let l:curline = getline(a:line)

    "highlight search but only on the current line '\%23l<pattern>'
    execute 'match Search /\%'.. a:line .."l".escape(a:search,'/$.~')."/"
    redraw

    " ask for permission
    echohl Question
    let l:prompt = input("replace with '".. a:substitution .. "'? [Y,a,n,q]: ",'')
    echohl None

    " clear l:prompt highlight
    match

    " decide what to do
    if len(l:prompt) == 0 || l:prompt ==? "y" || l:prompt ==? "a"

        let l:curline = substitute(l:curline,escape(a:search,'/$.~'),escape(a:substitution,'&~/~'),'')
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
    endfor
    return #{ENV2PATH : s:ENV2PATH, ENV2FILE: s:ENV2FILE, ENV2PATH_sorted_keys: s:ENV2PATH_sorted_keys}
endfunction
"}}}

" vim: :fdm=marker
