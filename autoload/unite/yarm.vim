"
" clear undo
"
function! unite#yarm#clear_undo()
  let old_undolevels = &undolevels
  setlocal undolevels=-1
  execute "normal a \<BS>\<Esc>"
  let &l:undolevels = old_undolevels
  unlet old_undolevels
endfunction
"
" parse option
"
function! unite#yarm#parse_args(args)
  let convert_def = {
        \ 'status'   : 'status_id'   ,
        \ 'project'  : 'project_id'  ,
        \ 'tracker'  : 'tracker_id'  ,
        \ 'assigned' : 'assigned_to_id'
        \ }
  let option = {}
  for arg in a:args
    if arg == ""
      continue
    endif
    let v = split(arg , '=')
    let v[0] = has_key(convert_def , v[0]) ? convert_def[v[0]] : v[0]
    let option[v[0]] = len(v) == 1 ? 1 : v[1]
  endfor
  return option
endfunction
"
" from xml.vim
"
function! unite#yarm#escape(str)
  let str = a:str
  let str = substitute(str, '&', '\&amp;', 'g')
  let str = substitute(str, '>', '\&gt;' , 'g')
  let str = substitute(str, '<', '\&lt;' , 'g')
  let str = substitute(str, '"', '\&#34;', 'g')
  return str
endfunction
"
" padding  ljust
"
function! unite#yarm#ljust(str, size, ...)
  let str = a:str
  let c   = a:0 > 0 ? a:000[0] : ' '
  while 1
    if strwidth(str) >= a:size
      return str
    endif
    let str .= c
  endwhile
  return str
endfunction
"
" padding rjust
"
function! unite#yarm#rjust(str, size, ...)
  let str = a:str
  let c   = a:0 > 0 ? a:000[0] : ' '
  while 1
    if strwidth(str) >= a:size
      return str
    endif
    let str = c . str
  endwhile
  return str
endfunction
"
" echo info log
"
function! unite#yarm#info(msg)
  echohl yarm_ok | echo a:msg | echohl None
  return 1
endfunction
"
" echo error log
"
function! unite#yarm#error(msg)
  echohl ErrorMsg | echo a:msg | echohl None
  return 0
endfunction
"
" backup issue
"
functio! unite#yarm#backup_issue(issue)
  if !exists('g:unite_yarm_backup_dir')
    return
  endif

  let body = split(a:issue.description , "\n")
  let path = g:unite_yarm_backup_dir . '/' . a:issue.id
        \ . '.' . strftime('%Y%m%d%H%M%S')
        \ . '.txt'
  call writefile(body , path)
endfunction
"
" open browser with issue's id
"
function! unite#yarm#open_browser(id)
  echohl yarm_ok 
  execute "OpenBrowser " . s:server_url() . '/issues/' . a:id
  echohl None
endfunction
"
" json to issue
"
function! unite#yarm#to_issue(issue)
  let issue = a:issue
  let issue.abbr = '#' . issue.id . ' '
  if exists('g:unite_yarm_title_fields')
    for key in g:unite_yarm_title_fields
      let value = ''
      if has_key(issue, key[0])
        if type(issue[key[0]]) == 4
          let value = issue[key[0]].name
        else
          let value = issue[key[0]]
        endif
        let value = value[0:key[1] - 2]
      endif
      let value = key[2][0] . value . key[2][1]
      let issue.abbr .= unite#yarm#ljust(value, key[1]) . ' '
    endfor
  endif
  let issue.abbr .= issue.subject
  let issue.word = issue.abbr
  " TODO
  let rest_url = s:server_url() . '/issues/' . issue.id . '.json?format=json?include=journals'
  if exists('g:unite_yarm_access_key')
    let rest_url .= '&key=' . g:unite_yarm_access_key
  endif
  let issue.rest_url = rest_url

  return issue
endfunction
"
" get issues with api
"
function! unite#yarm#get_issues(option)
  let limit = get(a:option , 'limit' , g:unite_yarm_limit)
  let url   = s:server_url() . '/issues.json?limit=' . limit
  if exists('g:unite_yarm_access_key')
    let url .= '&key=' . g:unite_yarm_access_key
  endif
  for key in keys(a:option)
    if a:option[key] == ''
      continue
    endif
    let url .= '&' . key . '=' . a:option[key]
  endfor
  let issues = []
  let offset = 0
  while 1
    let final_url = url . '&offset=' . offset
    let res = webapi#http#get(final_url)
    " server is not active
    if len(res.header) == 0
        call unite#yarm#error('can not access ' . s:server_url())
        return []
    endif
    " check status code
    if split(res.header[10])[1] != '200'
        call unite#yarm#error(res.header[0])
        return []
    endif
    " convert xml to dict
    let parsed = webapi#json#decode(res.content).issues
    if len(parsed) == 0
      break
    endif
    for issue in parsed
        call add(issues , unite#yarm#to_issue(issue))
    endfor
    let offset = offset + 100
  endwhile
  return issues
endfunction
"
" get issue with api
"
function! unite#yarm#get_issue(id)
  let url = s:server_url() . '/issues/' . a:id . '.json'
  if exists('g:unite_yarm_access_key')
    let url .= '?key=' . g:unite_yarm_access_key
  endif
  return unite#yarm#to_issue(webapi#json#decode(webapi#http#get(url).content).issue)
endfunction
"
" get sever url
"
" http://yarm.org  → http://yarm.org
" http://yarm.org/ → http://yarm.org
"
function! s:server_url()
  return substitute(g:unite_yarm_server_url , '/$' , '' , '')
endfunction


