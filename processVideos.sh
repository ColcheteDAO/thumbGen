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
genThumb='N'
folders=("man" "image" "outfile" "text")
declare -a errors
declare -a needUpdateThumb
declare -A customTitles
errors[0]="Quota Exceeded"
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

handleRequestErrors(){
  if [ $(checkPatternOcurrence "$1" '"error":') = 1 ]; then
    echo "error" 
  else
    echo "$1"
  fi
}

sendResquestWithPayload(){
  req=$(curl --request $1 \
    $2 --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data "$(echo $3)")
  echo "$(handleRequestErrors "$req")"
}

sendGetRequest(){
  req=$(curl "$1" \
    --header "Authorization: Bearer $ACCESS_TOKEN")
  echo "$(handleRequestErrors "$req")"
}

sendDataBinaryRequest(){
  req=$(curl --request $1 -v "$2" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "$3" \
  --data-binary "$4")
  echo "$(handleRequestErrors "$req")"
}

getPlaylistItemCount(){
  playlistReq=$(sendGetRequest "$urlBaseAPI/youtube/v3/playlistItems?part=snippet&playlistId=$1&videoId=$2")
  funName="getPlaylistItemCount"
  if [[ "$videosSearch" == "error" ]]; then
    echo "$videosSearch $funName ${errors[0]}"
    exit 1
  else
    playlistItemsCount=$(echo $playlistReq | jq -r '.items | length')
    echo $playlistItemsCount
  fi
}

addToPlaylist(){
  playlistItemsCount=$(getPlaylistItemCount $2 $3)
  if [ $playlistItemsCount = 0 ]; then
    playlistPayload=$(mountPlaylistPayload $2 $videoId)
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

mountCustomTitles(){
  indexCustomTitles=0
  while IFS= read -r lineTitle; do
    customTitles["$1$indexCustomTitles"]=$lineTitle
    indexCustomTitles=$((${indexCustomTitles}+1))
    echo "==========CUSTOM=========="
    echo $indexCustomTitles 
    echo $1 
    echo "$customTitles" 
    echo "$lineTitle" 
    echo "==========================="
  done < "out/titles/custom/$1.md"
}

mountVideosMeta(){
  funName="mountVideosMeta"
  declare -a titlesMakdown
  declare -a videosMakdown
  finalIndex=0
  errorMSG=""
  saveVideosMeta(){
    videoSeriesQuery=$(echo -n "$1" | jq -sRr @uri)
    videosSearch=$(sendGetRequest "$urlBaseAPI/youtube/v3/search?part=snippet&forMine=true&maxResults=50&order=date&q=$videoSeriesQuery&type=video&pageToken=$2")
    if [[ "$videosSearch" == "error" ]]; then
      errorMSG=$videosSearch
      echo "$videosSearch $funName ${errors[0]}"
    else
      while read videoSearchItem
      do
        lastIndex=${#line}
        folderStrLen=${#folder}
        videoTitleRaw=$(echo "$videoSearchItem" | jq -r '.snippet.title')
        videoTitleRawLen=${#videoTitleRaw}
        escapedFolder=$(echo $folder | sed "s|\[|\\\\[|" | sed "s|\]|\\\\]|")
        titleIndexRaw=$(echo "$videoTitleRaw"| grep -o -b ''"$escapedFolder"'' )
        titleIndexRawLen=${#titleIndexRaw}
        titleIndex=$(echo $titleIndexRaw | cut -c 1-$(expr $titleIndexRawLen - $folderStrLen - 1))
        seriesNumber=$(echo $videoTitleRaw | cut -c $(expr $titleIndex + $folderStrLen + 2)-$(expr $videoTitleRawLen + 2))
        titlesMakdown[${seriesNumber#0}]=$(echo "## ${videoTitleRaw/$folder /"#"}")
        videoIdAPI=$(echo "$videoSearchItem" | jq -r '.id.videoId')
        videosMakdown[${seriesNumber#0}]=$(echo "[video](https://youtu.be/$videoIdAPI)")
        if [[ $finalIndex -lt ${seriesNumber#0} ]]; then
          finalIndex=${seriesNumber#0}
        fi
      done < <(echo "$videosSearch" | jq -c '.items[]')
      nextPageToken=$(echo "$videosSearch" | jq -r '.nextPageToken')
      nextPageTokenLen=$(echo $nextPageToken | wc -m)
      if [[ $nextPageTokenLen -ge 10 ]]; then
       saveVideosMeta "$1" $nextPageToken 
      fi
    fi
  }
  saveVideosMeta "$1"
  if [[ "$errorMSG" != "error" ]]; then
    for (( c=1; c<=$finalIndex; c++ ))
    do 
      echo ${titlesMakdown[c]}
      echo ${videosMakdown[c]}
    done
  fi
}

while IFS= read -r line; do
  if [ $(checkPatternOcurrence "$line" '#') = 1 ]; then
    folder=$(echo "$line" | cut -c 3-$((${#line}+2)))
    folders+=("$folder")
    index=0
    mountCustomTitles "$folder"
    videosMetaData=$(mountVideosMeta "$folder")
    mkdir -p "out/titles/custom"
    touch "out/titles/custom/$folder.md"
    if [[ $(checkPatternOcurrence "$videosMetaData" '##') -lt 1 ]] && [[ $(checkPatternOcurrence "$videosMetaData" 'error') -ge 1 ]]; then
      echo "==================="
      echo $videosMetaData
      echo "==================="
      exit 1
    else
      fillDescription=true
      playlistIndex=0
      mkdir -p "out/titles"
      touch "out/titles/$folder.md"
      echo "$videosMetaData" > "out/titles/$folder.md"
      mkdir -p "titles"
      cp "out/titles/$folder.md" "titles/$folder.md" 
    fi
  elif $fillDescription ; then
    fillDescription=false
    description=$(echo $line)
  elif [ $(checkPatternOcurrence "$line" '\[playlist\]') = 1 ]; then
    playlistId=$(echo "$line" | cut -c 51-$((${#line}-3)))
    if [ $playlistIndex = 0 ]; then
      list1=$(echo $playlistId) 
    else
      list2=$(echo $playlistId)
      playlistIndex=0
    fi
    playlistIndex=$(($playlistIndex + 1))
  elif [ $(checkPatternOcurrence "$line" '\[artifact\]') = 1 ]; then
    artifactToDownload=$(echo "$line" | cut -c 12-$((${#line}-3)))
    wget $artifactToDownload
  elif [ $(checkPatternOcurrence "$line" '\*\*index\*\*: ') = 1 ]; then
    startUpdateIndex=$(echo "$line" | cut -c 11-$((${#line}-2)))
  elif [ $(checkPatternOcurrence "$line" '\*\*tags\*\*: ') = 1 ]; then
    tags=$(echo "$line" | cut -c 10-$((${#line}-2)))
  elif [ $(checkPatternOcurrence "$line" '\*\*genThumb\*\*: ') = 1 ]; then
    genThumb=$(echo "$line" | cut -c 14-$((${#line}-2)))
  elif [ $(checkPatternOcurrence "$line" '\*\*end\*\*') = 1 ]; then
    while IFS= read -r lineTitle; do
      if [ $(checkPatternOcurrence "$lineTitle" '#') = 3 ]; then
        index=$((${index}+1))
        title=$(echo "$lineTitle" | cut -c 4-$((${#lineTitle}+2)))
        if [ "$4" = "Y" ] || [ $genThumb = "Y" ]; then
          echo "=========Title Info=============="
          echo "${#customTitles[$folder$index]}" 
          echo "$customTitles[$folder$index]" 
          echo "$folder$index" 
          echo "=========Title Info=============="
          if [ ${#customTitles[$folder$index]} -gt 10 ]; then
            bash genThumb.sh "${customTitles[$folder$index]}" "$folder" 
          else
            bash genThumb.sh "$title" "$folder" 
          fi
          mkdir -p "out/thumbs/$folder"
          path="out/thumbs/$folder/$folder$index.png"
          diffCount=1
          if [ -f "out/thumbs/$folder/$folder$index.png" ]; then
             diffCount=$(compare -metric ae -fuzz XX% "out/thumbs/$folder/$folder$index.png" compose_under.png null: 2>&1) 
          fi
          mv compose_under.png "$path"
          echo "DEBUG THUMB========================"
          ls -l "out/thumbs/$folder/$folder$index.png"
          echo $diffCount
          echo "DEBUG THUMB========================"
          if [ "$diffCount" = 0 ]; then
            needUpdateThumb[$index]=false
          else
            needUpdateThumb[$index]=true
          fi
        fi
      elif [ $(checkPatternOcurrence "$lineTitle" '\[video\]') = 1 ]; then
        videoId=$(echo "$lineTitle" | cut -c 26-$((${#lineTitle}-1)))
        fillSnippetVideo $videoId  
        if [[ ! -z "$description" ]] && [ $descriptionLen -lt 10 ] || [ "$4" = "Y" ] || [ $index -ge $startUpdateIndex ]; then
          if [ "$4" = "Y" ] || [ $genThumb = "Y" ]; then
            if [ "${needUpdateThumb[$index]}" = true ]; then
              echo "==============.................."
              echo "UPDATED THE THUMB"
              echo "==============.................."
              sendDataBinaryRequest "POST" "$urlBaseAPI/upload/youtube/v3/thumbnails/set?videoId=$videoId&uploadType=media" "Content-Type: image/jpeg" "@$path"
            fi
          fi
          sendResquestWithPayload "PUT" "$urlBaseAPI/youtube/v3/videos?part=snippet" "$(updateVideoPayload "$videoId" "$description" "$titleVideo" "28" "pt-BR" "pt-BR" "$tags")"
          addToPlaylist "POST" $list1 $videoId
          addToPlaylist "POST" $list2 $videoId
        fi
      fi
    done < "titles/$folder.md"
  fi
done < videos.md
for (( f=0; f<${#folders[@]} ; f++ ))
do 
  rm -rf "${folders[$f]}"*
done
rm -rf titles
