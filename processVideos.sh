index=0
folder=''
path=''
while IFS= read -r line; do
  headingCounter=$(echo $line | grep -o '#' | wc -l)
  videoCount=$(echo $line | grep -o '\[video\]' | wc -l)
  if [ $headingCounter = 1 ]; then
    lastChar=$((${#line}+2))
    folder=$(echo "$line" | cut -c 3-$lastChar)
    index=0
  elif [ $headingCounter = 2 ]; then
    index=$((${index}+1))
    lastChar=$((${#line}+2))
    title=$(echo "$line" | cut -c 4-$lastChar)
    bash genThumb.sh "$title" "$folder" 
    mkdir -p "out/$folder"
    path="out/$folder/$folder$index".png
    mv compose_under.png $path
  elif [ $videoCount = 1 ]; then
    lastChar=$((${#line}-1))
    echo "$line" | cut -c 26-$lastChar
  fi
done < videos.md
