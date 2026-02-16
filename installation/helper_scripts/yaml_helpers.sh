#!/usr/bin/env bash
# helper_scripts/yaml_ops.sh
set -euo pipefail

yaml_backup_once() {
  local file="${1:?file}"
  [[ -f "$file" ]] || { echo "Missing file: $file" >&2; return 1; }
  if [[ ! -f "${file}.bak" ]]; then
    cp "$file" "${file}.bak"
  fi
}

# Replace ALL occurrences: "<indent> key: <anything>" -> "<indent> key: value"
yaml_set_all_scalar_keys() {
  local file="${1:?file}"
  local key="${2:?key}"
  local value="${3:-}"
  [[ -f "$file" ]] || { echo "Missing file: $file" >&2; return 1; }
  sed -i -E "s/^([[:space:]]*${key}:[[:space:]]*).*/\1${value//\//\\/}/" "$file"
}

yaml_path_exists() {
  # Returns 0 if a map key path exists, e.g. "global.n6network" or "mongodb.mongodb"
  local file="${1:?file}"
  local path="${2:?path}"
  [[ -f "$file" ]] || { echo "Missing file: $file" >&2; return 2; }

  awk -v PATH="$path" '
  function is_blank_or_comment(s){ return (s ~ /^[[:space:]]*$/ || s ~ /^[[:space:]]*#/) }
  function is_key_line(s,   m){ return match(s, /^([[:space:]]*)([A-Za-z0-9_.-]+):([[:space:]]*.*)$/, m) }
  function key_name(s,   m){ match(s, /^([[:space:]]*)([A-Za-z0-9_.-]+):/, m); return m[2] }
  function key_indent(s, m){ match(s, /^([[:space:]]*)([A-Za-z0-9_.-]+):/, m); return length(m[1]) }

  function push(k, ind){ ++top; stk_k[top]=k; stk_i[top]=ind }
  function pop(){ if(top>0){ delete stk_k[top]; delete stk_i[top]; --top } }
  function joinpath(  i,p){ p=""; for(i=1;i<=top;i++){ p=(p==""?stk_k[i]:p "." stk_k[i]) } return p }

  BEGIN{ top=0; found=0 }
  {
    if (is_blank_or_comment($0)) next
    if (!is_key_line($0)) next

    ind=key_indent($0)
    k=key_name($0)

    while(top>0 && ind <= stk_i[top]) pop()
    push(k, ind)

    if (joinpath()==PATH) { found=1; exit }
  }
  END{ exit(found?0:1) }
  ' "$file"
}

yaml_upsert_scalar_path() {
  # Upsert scalar at dot-path "a.b.c: value" without duplicating top-level keys.
  # - If key exists => replace that line
  # - If missing => insert into correct parent map (creating intermediate maps as needed)
  #
  # IMPORTANT: block_end() treats top-level comments as boundaries so inserts don’t fall
  # under the wrong section header comment.
  local file="${1:?file}"
  local path="${2:?dot.path}"
  local value="${3:?value}"
  [[ -f "$file" ]] || { echo "Missing file: $file" >&2; return 1; }

  local tmp
  tmp="$(mktemp)"

  awk -v PATH="$path" -v VAL="$value" '
  function is_blank(s){ return (s ~ /^[[:space:]]*$/) }
  function is_comment(s){ return (s ~ /^[[:space:]]*#/) }
  function indent_len(s,   m){ match(s, /^[[:space:]]*/, m); return RLENGTH }

  function is_key_line(s,   m){ return match(s, /^([[:space:]]*)([A-Za-z0-9_.-]+):([[:space:]]*.*)$/, m) }
  function key_name(s,   m){ match(s, /^([[:space:]]*)([A-Za-z0-9_.-]+):/, m); return m[2] }
  function key_indent(s, m){ match(s, /^([[:space:]]*)([A-Za-z0-9_.-]+):/, m); return length(m[1]) }

  function find_key(start, end, ind, k,   i){
    for(i=start;i<=end;i++){
      if (is_blank(L[i])) continue
      if (is_comment(L[i])) continue
      if (!is_key_line(L[i])) continue
      if (key_indent(L[i])==ind && key_name(L[i])==k) return i
    }
    return 0
  }

  function block_end(line_idx, ind,   i, curind){
    for(i=line_idx+1;i<=N;i++){
      if (is_blank(L[i])) continue

      # Top-level / boundary comments should not be swallowed into the previous block.
      if (is_comment(L[i]) && indent_len(L[i]) <= ind) return i-1

      if (is_key_line(L[i])) {
        curind=key_indent(L[i])
        if (curind<=ind) return i-1
      }
    }
    return N
  }

  function insert_lines(pos, arr, arrn,   i){
    for(i=N;i>pos;i--) L[i+arrn]=L[i]
    for(i=1;i<=arrn;i++) L[pos+i]=arr[i]
    N+=arrn
  }

  BEGIN{
    N=0
    nseg = split(PATH, seg, ".")
  }
  { L[++N] = $0 }

  END{
    if(N==0){
      for(i=1;i<nseg;i++) printf "%*s%s:\n", (i-1)*2, "", seg[i]
      printf "%*s%s: %s\n", (nseg-1)*2, "", seg[nseg], VAL
      exit
    }

    top_line = find_key(1, N, 0, seg[1])
    if(top_line==0){
      L[++N] = ""
      for(i=1;i<nseg;i++) L[++N]=sprintf("%*s%s:", (i-1)*2, "", seg[i])
      L[++N]=sprintf("%*s%s: %s", (nseg-1)*2, "", seg[nseg], VAL)
      for(i=1;i<=N;i++) print L[i]
      exit
    }

    cur_line = top_line
    cur_indent = key_indent(L[cur_line])
    cur_end = block_end(cur_line, cur_indent)

    for(si=2; si<=nseg; si++){
      want = seg[si]
      child_indent = cur_indent + 2
      child_line = find_key(cur_line+1, cur_end, child_indent, want)

      if(si < nseg){
        if(child_line==0){
          INSN=1
          INS[1]=sprintf("%*s%s:", child_indent, "", want)
          insert_lines(cur_end, INS, INSN)
          child_line = cur_end + 1
          cur_end = block_end(cur_line, cur_indent)
        }
        cur_line = child_line
        cur_indent = key_indent(L[cur_line])
        cur_end = block_end(cur_line, cur_indent)
      } else {
        if(child_line==0){
          INSN=1
          INS[1]=sprintf("%*s%s: %s", child_indent, "", want, VAL)
          insert_lines(cur_end, INS, INSN)
        } else {
          L[child_line]=sprintf("%*s%s: %s", child_indent, "", want, VAL)
        }
      }
    }

    for(i=1;i<=N;i++) print L[i]
  }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

yaml_try_upsert_scalar_path_if_parent_exists() {
  # Only upsert if parent path exists as a map key.
  local file="${1:?file}"
  local path="${2:?path}"
  local value="${3:?value}"
  local parent="${4:?parent-path}"
  if yaml_path_exists "$file" "$parent"; then
    yaml_upsert_scalar_path "$file" "$path" "$value"
    return 0
  fi
  return 1
}
