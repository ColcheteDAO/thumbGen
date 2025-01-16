while IFS= read -r line; do
  lastChar=$((${#line}+2))
  title=$(echo "$line" | cut -c 3-$lastChar)
  bash genThumb.sh "$title" 
  mv compose_under.png "out/$title".png 
done < videos.md
