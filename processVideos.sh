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
startUpdateIndex=0
tags=''
urlBaseAPI='https://youtube.googleapis.com'
urlBaseAuth='https://oauth2.googleapis.com'
ACCESS_TOKEN=$(curl  --location --request POST "$urlBaseAuth/token?client_secret=$1&grant_type=refresh_token&refresh_token=$2&client_id=$3" | jq .access_token | tr -d '"')
mountPlaylistPayload(){
  updatePlaylistJSON=$(printf '{
                                "snippet":
                                {
                                  "playlistId":"%s",
                                  "resourceId":
                                  {
                                    "kind":"youtube#video",
                                    "videoId":"%s"
                                  }
                                }
                              }' "$1" "$2")
  echo $updatePlaylistJSON
}

addToPlaylist(){
  playlistReq=$(curl "$urlBaseAPI/youtube/v3/playlistItems?part=snippet&playlistId=$2&videoId=$3" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Accept: application/json")
  playlistItemsCount=$(echo $playlistReq | jq -r '.items | length')
  if [ $4 = 0 ]; then
    curl --request $1 \
    "$urlBaseAPI/youtube/v3/playlistItems?part=snippet" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data "$(echo $5)"
  fi
}
while IFS= read -r line; do
  headingCounter=$(echo $line | grep -o '#' | wc -l)
  videoCount=$(echo $line | grep -o '\[video\]' | wc -l)
  playlistCount=$(echo $line | grep -o '\[playlist\]' | wc -l)
  startUpdateIndexCount=$(echo $line | grep -o '\*\*index\*\*: ' | wc -l)
  tagsCount=$(echo $line | grep -o '\*\*tags\*\*: ' | wc -l)
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
    lastChar=$((${#line}-3))
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
  elif [ $startUpdateIndexCount = 1 ]; then
    lastChar=$((${#line}-2))
    startUpdateIndex=$(echo "$line" | cut -c 11-$lastChar)
  elif [ $tagsCount = 1 ]; then
    lastChar=$((${#line}-2))
    tags=$(echo "$line" | cut -c 10-$lastChar)
  elif [ $videoCount = 1 ]; then
    lastChar=$((${#line}-1))
    videoId=$(echo "$line" | cut -c 26-$lastChar)
    listReq=$(curl "$urlBaseAPI/youtube/v3/videos?part=snippet%2CcontentDetails%2Cstatistics&id=$videoId" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Accept: application/json")
    categoryId=$(echo $listReq | jq -r .items[0].snippet.categoryId)
    titleVideo=$(echo $listReq | jq -r .items[0].snippet.title)
    echo $titleVideo
    descriptionLen=$(echo $listReq | jq .items[0].snippet.description | wc -m)
    if [[ ! -z "$description" ]] && [ $descriptionLen -lt 10 ] || [ "$4" = "Y" ] || [ $index -ge $startUpdateIndex ]; then
      curl --request POST -v "$urlBaseAPI/upload/youtube/v3/thumbnails/set?videoId=$videoId&uploadType=media" \
      --header "Authorization: Bearer $ACCESS_TOKEN" \
      --header "Content-Type: image/jpeg" \
      --data-binary "@$path"
      updateVideoJSON=$(printf '{
                                  "id":"%s",
                                  "snippet":
                                  {
                                    "description":"%s",
                                    "title":"%s",
                                    "categoryId":"%s",
                                    "defaultLanguage":"%s",
                                    "defaultAudioLanguage":"%s",
                                    "tags":[%s]
                                  }
                                }' "$videoId" "$description" "$titleVideo" "28" "pt-BR" "pt-BR" "$tags")
      curl --request PUT \
      "$urlBaseAPI/youtube/v3/videos?part=snippet" \
      --header "Authorization: Bearer $ACCESS_TOKEN" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --data "$(echo $updateVideoJSON)"
      
      addToPlaylist "POST" $list1 $videoId $playlistItemsCount $(mountPlaylistPayload $1 $2)
      addToPlaylist "POST" $list2 $videoId $playlistItemsCount $(mountPlaylistPayload $1 $2)
    fi
  fi
done < videos.md
