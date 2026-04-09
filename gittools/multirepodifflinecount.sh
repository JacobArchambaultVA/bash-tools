
ls | grep -i ped-services | while read d; do
  total=$(git -C "$d" diff Release_ObjStore_Migration --shortstat 2>/dev/null | \
    awk '{for(i=1;i<=NF;i++) if($i~/^[0-9]+$/ && $(i+1)~/^insertion|^deletion/) s+=$i} END{print s+0}')
  echo "$d: $total"
done
