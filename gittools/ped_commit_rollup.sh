#!/usr/bin/env bash
set -euo pipefail

# Roll up commit counts across ped* repositories to a roughly per-person list.
# Heuristic:
# - Canonical identities come from names shaped like "First Last" or "Last, First".
# - Handle-like names are mapped by matching last name + first initial when unique.
# - Bot/build users are excluded.
#
# Usage:
#   ped_commit_rollup.sh [base_dir]
#
# Examples:
#   ped_commit_rollup.sh
#   ped_commit_rollup.sh /c/Users/OITLOUArchaJ/source/repos

BASE_DIR="${1:-$PWD}"

if [[ ! -d "$BASE_DIR" ]]; then
  echo "Error: base directory not found: $BASE_DIR" >&2
  exit 1
fi

cd "$BASE_DIR"

for repo in ped*; do
  [[ -d "$repo" ]] || continue
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
  git --no-pager -C "$repo" log --no-merges --format='%aN%x09%aE'
done | awk -F '\t' '
function trim(s){ sub(/^[[:space:]]+/,"",s); sub(/[[:space:]]+$/,"",s); return s }
function lc(s){ return tolower(s) }
function is_bot(n,e, x){
  x=lc(n " " e)
  return (x ~ /\[bot\]/ || x ~ /bot@/ || x ~ /jenkins|build|nightly|dependabot|copilot-swe-agent|github-actions/)
}
function canonical_key(n, parts,np,last,first,fi){
  n=trim(n)
  gsub(/[()]/," ",n)
  if (n ~ /^[A-Za-z][A-Za-z'"'"'`.-]*, *[A-Za-z][A-Za-z'"'"'`.-]*/) {
    split(n, parts, /, */)
    last=lc(parts[1])
    split(parts[2], np, / +/)
    first=lc(np[1])
    fi=substr(first,1,1)
    return fi "|" last
  }
  if (n ~ /^[A-Za-z][A-Za-z'"'"'`.-]*( [A-Za-z][A-Za-z'"'"'`.-]*)+$/) {
    split(n, np, / +/)
    first=lc(np[1])
    last=lc(np[length(np)])
    fi=substr(first,1,1)
    return fi "|" last
  }
  return ""
}
function localpart(e, lp){ lp=lc(e); sub(/@.*/,"",lp); return lp }
function infer_key(name,email, target,lp,fi,k,cands,nc,n2,i){
  target=lc(name " " localpart(email))
  nc=0
  for (k in key_last) {
    if (index(target,key_last[k])>0) cands[++nc]=k
  }
  if (nc==1) return cands[1]
  if (nc>1) {
    lp=localpart(email)
    fi=substr(lp,1,1)
    if (fi=="") fi=substr(lc(name),1,1)
    n2=0
    for (i=1;i<=nc;i++) {
      if (substr(cands[i],1,1)==fi) cands[++n2]=cands[i]
    }
    if (n2==1) return cands[1]
  }
  return ""
}
{
  name=trim($1)
  email=lc(trim($2))
  if (email=="" || is_bot(name,email)) next
  count[email]++
  if (!(email in best_name)) best_name[email]=name
}
END {
  for (e in count) {
    n=best_name[e]
    k=canonical_key(n)
    if (k!="") {
      total[k]+=count[e]
      if (!(k in rep_name) || index(n,",")>0) rep_name[k]=n
      if (!(k in rep_email)) rep_email[k]=e
      key_last[k]=substr(k,3)
    }
  }
  for (e in count) {
    n=best_name[e]
    k=canonical_key(n)
    if (k!="") continue
    ik=infer_key(n,e)
    if (ik!="") {
      total[ik]+=count[e]
    } else {
      total["~" e]+=count[e]
      rep_name["~" e]=n
      rep_email["~" e]=e
    }
  }
  for (k in total) {
    printf "%d\t%s\t%s\n", total[k], rep_name[k], rep_email[k]
  }
}' | sort -t $'\t' -k1,1nr | awk -F '\t' '
BEGIN {
  printf "%8s  %-36s  %s\n", "commits", "name", "email"
  printf "%8s  %-36s  %s\n", "-------", "----", "-----"
}
{
  printf "%8d  %-36s  <%s>\n", $1, $2, $3
}'
