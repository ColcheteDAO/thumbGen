index=0
folder=''
path=''
ACCESS_TOKEN=$(curl  --location --request POST "https://oauth2.googleapis.com/token?client_secret=$1&grant_type=refresh_token&refresh_token=$2&client_id=$3" | jq .access_token | tr -d '"')
while IFS= read -r line; do
  headingCounter=$(echo $line | grep -o '#' | wc -l)
  videoCount=$(echo $line | grep -o '\[video\]' | wc -l)
  if [ $headingCounter = 1 ]; then
    lastChar=$((${#line}+2))
    folder=$(echo "$line" | cut -c 3-$lastChar)
    index=0
  elif [ $headingCounter = 3 ]; then
    index=$((${index}+1))
    lastChar=$((${#line}+2))
    title=$(echo "$line" | cut -c 4-$lastChar)
    bash genThumb.sh "$title" "$folder" 
    mkdir -p "out/$folder"
    path="out/$folder/$folder$index.png"
    mv compose_under.png $path
  elif [ $videoCount = 1 ]; then
    lastChar=$((${#line}-1))
    videoId=$(echo "$line" | cut -c 26-$lastChar)
    echo $videoId
    curl --request POST -v "https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId='$videoId'&uploadType=media" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header 'Content-Type: image/jpeg' \
    --data-binary "@$path"
  fi
done < videos.md
