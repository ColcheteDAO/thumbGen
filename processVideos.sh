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
genThumb='Y'
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

updateVideoPayload(){
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
                          }' "$1" "$2" "$3" "$4" "$5" "$6" "$7")
  echo $updateVideoJSON
}

sendResquestWithPayload(){
  curl --request $1 \
    $2 --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data "$(echo $3)"
}

sendGetRequest(){
  req=$(curl "$1" \
    --header "Authorization: Bearer $ACCESS_TOKEN")
  echo $req
}

sendDataBinaryRequest(){
  req=$(curl --request $1 -v "$2" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "$3" \
  --data-binary "$4")
  echo $req
}

getPlaylistItemCount(){
  playlistReq=$(sendGetRequest "$urlBaseAPI/youtube/v3/playlistItems?part=snippet&playlistId=$1&videoId=$2")
  playlistItemsCount=$(echo $playlistReq | jq -r '.items | length')
  echo playlistItemsCount
}

addToPlaylist(){
  playlistItemsCount=$(getPlaylistItemCount $2 $3)
  if [ $playlistItemsCount = 0 ]; then
    playlistPayload=$(mountPlaylistPayload $list1 $videoId)
    sendResquestWithPayload $1 "$urlBaseAPI/youtube/v3/playlistItems?part=snippet" "$playlistPayload"   
  fi
}

fillSnippetVideo(){
  listReq=$(sendGetRequest "$urlBaseAPI/youtube/v3/videos?part=snippet%2CcontentDetails%2Cstatistics&id=$1")
  categoryId=$(echo $listReq | jq -r .items[0].snippet.categoryId)
  titleVideo=$(echo $listReq | jq -r .items[0].snippet.title)
  descriptionLen=$(echo $listReq | jq .items[0].snippet.description | wc -m)
}
checkPatternOcurrence(){
  echo $1 | grep -o $2 | wc -l
}

mountVideosMeta(){
  videosSearch=$(sendGetRequest "$urlBaseAPI/youtube/v3/search?part=snippet&forMine=true&maxResults=50&order=date&q=$1&type=video")
  while read videoSearchItem
  do
    videoTitleRaw=$(echo "$videoSearchItem" | jq -c '.snippet.title')
    echo "## ${videoTitleRaw/thumbGen /"#"}"
    echo "$videoSearchItem" | jq -c '.snippet.description'
  done < <(echo "$videosSearch" | jq -c '.items[]')

}

while IFS= read -r line; do
  if [ $(checkPatternOcurrence "$line" '#') = 1 ]; then
    folder=$(echo "$line" | cut -c 3-$((${#line}+2)))
    mountVideosMeta $folder
    index=0
    fillDescription=true
    playlistIndex=0
  elif $fillDescription ; then
    fillDescription=false
    description=$(echo $line)
  elif [ $(checkPatternOcurrence "$line" '\[playlist\]') = 1 ]; then
    playlistId=$(echo "$line" | cut -c 51-$((${#line}-3)))
    if [ $playlistIndex = 0 ]; then
      list1=$(echo $playlistId) 
    else
      list2=$(echo $playlistId) 
    fi
    playlistIndex=$(($playlistIndex + 1))
  elif [ $(checkPatternOcurrence "$line" '#') = 3 ]; then
    index=$((${index}+1))
    title=$(echo "$line" | cut -c 4-$((${#line}+2)))
    if [ "$4" = "Y" ] || [ $genThumb = "Y" ]; then
      bash genThumb.sh "$title" "$folder" 
      mkdir -p "out/$folder"
      path="out/$folder/$folder$index.png"
      mv compose_under.png $path
    fi
  elif [ $(checkPatternOcurrence "$line" '\*\*index\*\*: ') = 1 ]; then
    startUpdateIndex=$(echo "$line" | cut -c 11-$((${#line}-2)))
  elif [ $(checkPatternOcurrence "$line" '\*\*tags\*\*: ') = 1 ]; then
    tags=$(echo "$line" | cut -c 10-$((${#line}-2)))
  elif [ $(checkPatternOcurrence "$line" '\*\*genThumb\*\*: ') = 1 ]; then
    genThumb=$(echo "$line" | cut -c 14-$((${#line}-2)))
  elif [ $(checkPatternOcurrence "$line" '\[video\]') = 1 ]; then
    videoId=$(echo "$line" | cut -c 26-$((${#line}-1)))
    fillSnippetVideo $videoId  
    if [[ ! -z "$description" ]] && [ $descriptionLen -lt 10 ] || [ "$4" = "Y" ] || [ $index -ge $startUpdateIndex ]; then
      if [ "$4" = "Y" ] || [ $genThumb = "Y" ]; then
        sendDataBinaryRequest "POST" "$urlBaseAPI/upload/youtube/v3/thumbnails/set?videoId=$videoId&uploadType=media" "Content-Type: image/jpeg" "@$path"
      fi
      sendResquestWithPayload "PUT" "$urlBaseAPI/youtube/v3/videos?part=snippet" "$(updateVideoPayload "$videoId" "$description" "$titleVideo" "28" "pt-BR" "pt-BR" "$tags")"
      addToPlaylist "POST" $list1 $videoId
      addToPlaylist "POST" $list2 $videoId
    fi
  fi
done < videos.md
