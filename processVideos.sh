index=0
folder=''
while IFS= read -r line; do
  headingCounter=$(echo $line | grep -o '#' | wc -l)
  if [ $headingCounter = 1 ]; then
    lastChar=$((${#line}+2))
    folder=$(echo "$line" | cut -c 3-$lastChar)
    index=0
  else
    index=$((${index}+1))
    lastChar=$((${#line}+2))
    title=$(echo "$line" | cut -c 4-$lastChar)
    bash genThumb.sh "$title" "$folder" 
    mkdir -p "out/$folder"
    mv compose_under.png "out/$folder/$folder$index".png 
  fi
done < videos.md
