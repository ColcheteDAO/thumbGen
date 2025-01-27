index=0
folder=''
path=''
description=''
playlistAll=''
playlistSpecific=''
fillDescription=false
list1=''
list2=''
declare -A playlists
ACCESS_TOKEN=$(curl  --location --request POST "https://oauth2.googleapis.com/token?client_secret=$1&grant_type=refresh_token&refresh_token=$2&client_id=$3" | jq .access_token | tr -d '"')
while IFS= read -r line; do
  headingCounter=$(echo $line | grep -o '#' | wc -l)
  videoCount=$(echo $line | grep -o '\[video\]' | wc -l)
  playlistCount=$(echo $line | grep -o '\[playlist\]' | wc -l)
  if [ $headingCounter = 1 ]; then
    lastChar=$((${#line}+2))
    folder=$(echo "$line" | cut -c 3-$lastChar)
    index=0
    fillDescription=true
    playlistIndex=0
  elif $fillDescription ; then
    fillDescription=false
    description=$(echo $line)
  elif [ $playlistCount = 1 ]; then
    lastChar=$((${#line}-1))
    playlistId=$(echo "$line" | cut -c 51-$lastChar)
    if [ $playlistIndex = 0 ]; then
      list1=$(echo $playlistId) 
    else
      list2=$(echo $playlistId) 
    fi
    playlistIndex=$(($playlistIndex + 1))
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
    listReq=$(curl "https://youtube.googleapis.com/youtube/v3/videos?part=snippet%2CcontentDetails%2Cstatistics&id=$videoId" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Accept: application/json")
    categoryId=$(echo $listReq | jq -r .items[0].snippet.categoryId)
    titleVideo=$(echo $listReq | jq -r .items[0].snippet.title)
    echo $titleVideo
    descriptionLen=$(echo $listReq | jq .items[0].snippet.description | wc -m)
    if [ $descriptionLen -lt 10 ]; then
      curl --request POST -v "https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId=$videoId&uploadType=media" \
      --header "Authorization: Bearer $ACCESS_TOKEN" \
      --header "Content-Type: image/jpeg" \
      --data-binary "@$path"
      curl --request PUT \
      'https://youtube.googleapis.com/youtube/v3/videos?part=snippet' \
      --header "Authorization: Bearer $ACCESS_TOKEN" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --data '{"id":"'$videoId'","snippet":{"description":"'"$description"'","title":"'"$titleVideo"'","categoryId":"28"}}'
      curl --request POST \
      "https://youtube.googleapis.com/youtube/v3/playlistItems?part=snippet" \
      --header "Authorization: Bearer $ACCESS_TOKEN" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --data '{"snippet":{"playlistId":"'"$list1"'","position":0,"resourceId":{"kind":"youtube#video","videoId":"'$videoId'"}}}'
      curl --request POST \
      "https://youtube.googleapis.com/youtube/v3/playlistItems?part=snippet" \
      --header "Authorization: Bearer $ACCESS_TOKEN" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --data '{"snippet":{"playlistId":"'"$list2"'","position":0,"resourceId":{"kind":"youtube#video","videoId":"'$videoId'"}}}'
    fi
  fi
done < videos.md
