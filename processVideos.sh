index=0
imageIndex=0
customIndex=0
folder=''
path=''
description=''
playlistAll=''
playlists='[]'
startUpdateIndex=0
tags=''
genThumb=false
run=false
folders=("man" "image" "outfile" "text")
declare -a errors
declare -a needUpdateThumb
declare -A customTitles
errors[0]="Quota Exceeded"
urlBaseAPI='https://youtube.googleapis.com'
urlBaseAuth='https://oauth2.googleapis.com'
ACCESS_TOKEN=$(curl -s --location --request POST "$urlBaseAuth/token?client_secret=$1&grant_type=refresh_token&refresh_token=$2&client_id=$3" | jq .access_token | tr -d '"')
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
                              "description":%s,
                              "title":"%s",
                              "categoryId":"%s",
                              "defaultLanguage":"%s",
                              "defaultAudioLanguage":"%s",
                              "tags":%s
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
  req=$(curl -s --request $1 \
    $2 --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data "$(echo $3)")
  echo "$(handleRequestErrors "$req")"
}

sendGetRequest(){
  req=$(curl -s "$1" \
    --header "Authorization: Bearer $ACCESS_TOKEN")
  echo "$(handleRequestErrors "$req")"
}

sendDataBinaryRequest(){
  req=$(curl -s --request $1 -v "$2" \
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
    indexCustomTitles=$((${indexCustomTitles}+1))
    customTitles["$1$indexCustomTitles"]=$lineTitle
  done < "out/titles/custom/$1.md"
}

mountVideoCustomProps(){
  videoSeriesAmount=$(echo "$(expr $(wc -l < "out/titles/$1.md") / 2)")
  defaultCustomVideoProp={"description":$(cat "config/$folder.json" | jq '.description'),"tags":$(cat "config/$folder.json" | jq '.tags'),"custom":false,"updatedThumb":false}
  for i in $(seq 0 "$videoSeriesAmount");
  do
    isCustomProps=$(jq '.['$i'].custom // false' "out/custom/$1.json")
    [[ $isCustomProps == false ]] && {
      echo "$(jq '.['$i'] = '"$defaultCustomVideoProp"'' "out/custom/$1.json")" > "out/custom/$1.json" 
    }
  done
}

mountVideosMeta(){
  funName="mountVideosMeta"
  declare -a titlesMakdown
  declare -a videosMakdown
  finalIndex=0
  errorMSG=""
  saveVideosMeta(){
    videoSeriesQuery=$(echo -n "$1" | jq -sRr @uri)
    videosSearchRaw=$(sendGetRequest "$urlBaseAPI/youtube/v3/search?part=snippet&forMine=true&maxResults=50&order=date&q=$videoSeriesQuery&type=video&pageToken=$2")
    if [[ "$videosSearchRaw" == "error" ]]; then
      errorMSG=$videosSearchRaw
      echo "$videosSearchRaw $funName ${errors[0]}"
    else
      videosSearch=$(echo $videosSearchRaw | jq -c '.items[] | select( .snippet.title | contains("'"$1"'"))')
      while read videoSearchItem
      do
        videoTitleRaw=$(echo "$videoSearchItem" | jq -r '.snippet.title')
        seriesNumber=${videoTitleRaw##* }
        seriesNumber=${seriesNumber#0}
        titlesMakdown[$seriesNumber]=$(echo "## ${videoTitleRaw/$folder /"#"}")
        videoIdAPI=$(echo "$videoSearchItem" | jq -r '.id.videoId')
        videosMakdown[$seriesNumber]=$(echo "[video](https://youtu.be/$videoIdAPI)")
        if [[ $finalIndex -lt $seriesNumber ]]; then
          finalIndex=$seriesNumber
        fi
      done < <(echo "$videosSearch")
      nextPageToken=$(echo "$videosSearchRaw" | jq -r '.nextPageToken')
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
    mkdir -p "config"
    touch "config/$folder.json"
    if [[ $(cat "config/$folder.json" | jq 'has("description") and has("playlists") and has("startUpdateIndex") and has("tags") and has("genThumb") and has("forceGenThumb") and has("run")' -r) = "true" ]]; then
      run=$(cat "config/$folder.json" | jq '.run')
      genThumb=$(cat "config/$folder.json" | jq '.genThumb')
      forceGenThumb=$(cat "config/$folder.json" | jq '.forceGenThumb')
      description=$(cat "config/$folder.json" | jq '.description' -r)
      tags=$(cat "config/$folder.json" | jq '.tags')
      startUpdateIndex=$(cat "config/$folder.json" | jq '.startUpdateIndex')
      playlists=$(cat "config/$folder.json" | jq '.playlists')
    else
      cat base.json > "config/$folder.json"
    fi
    # if [[ $run = true && $(cat "config/$folder.json" | jq '.customUpdateIndexes | length') -eq 0 ]]; then
    if [[ $run = true ]]; then
      mkdir -p "out/titles/custom"
      mkdir -p "out/custom"
      touch "out/titles/custom/$folder.md"
      touch "out/custom/$folder.json"
      [[ $(jq -e . <<< "out/custom/$folder.json" >/dev/null 2>&1; echo $?) -ne 0 && $(cat "out/custom/$folder.json" | jq 'length') -eq 0 ]] && {
        echo "[]" > "out/custom/$folder.json"
      }
      mountCustomTitles "$folder"
      mountVideoCustomProps "$folder"
      videosMetaData=$(mountVideosMeta "$folder")
      if [[ $(checkPatternOcurrence "$videosMetaData" '##') -lt 1 ]] && [[ $(checkPatternOcurrence "$videosMetaData" 'error') -ge 1 ]]; then
        echo "==================="
        echo $videosMetaData
        echo "==================="
        exit 1
      else
        mkdir -p "out/titles"
        touch "out/titles/$folder.md"
        echo "$videosMetaData" > "out/titles/$folder.md"
        mkdir -p "titles"
        cp "out/titles/$folder.md" "titles/$folder.md" 
      fi
    fi
  elif [ $(checkPatternOcurrence "$line" '\[artifact\]') = 1 ]; then
    artifactToDownload=$(echo "$line" | cut -c 12-$((${#line}-3)))
    wget -q $artifactToDownload
    wget -q $artifactToDownload -o out/$(echo $artifactToDownload | sed 's/.*\///' | sed 's/...$//')
  elif [ $(checkPatternOcurrence "$line" '\*\*end\*\*') = 1 ]; then
    if [ $run = true ]; then
      while IFS= read -r lineTitle; do
        listLength=$(cat "config/$folder.json" | jq '.customUpdateIndexes | length')
        customUpdateIndex=-1
        if [[ "$listLength" -gt 0 ]]; then
          customUpdateIndex=$(cat "config/$folder.json" | jq ".customUpdateIndexes[$customIndex]")
        fi
        if [ $(checkPatternOcurrence "$lineTitle" '#') = 3 ]; then
          imageIndex=$(echo "$lineTitle" | grep -oP '#\K\d+') 
          path="out/thumbs/$folder/$folder$imageIndex.png"
          index=$((${index}+1))
        fi
       if [[ ( "$listLength" -eq 0 && "$imageIndex" -ge "$startUpdateIndex" ) || \
             ( "$listLength" -gt 0 && "$imageIndex" -eq "$customUpdateIndex" ) ]]; then
          if [ $(checkPatternOcurrence "$lineTitle" '#') = 3 ]; then
            title=$(echo "$lineTitle" | cut -c 4-$((${#lineTitle}+2)))
            if [ "$4" = "Y" ] || [ $genThumb = true ]; then
              if [ ${#customTitles[$folder$imageIndex]} -gt 10 ]; then
                bash genThumb.sh "${customTitles[$folder$imageIndex]}" "$folder" 
              else
                bash genThumb.sh "$title" "$folder" 
              fi
              mkdir -p "out/thumbs/$folder"
              echo "=========================="
              echo "out/thumbs/$folder"
              echo "$path"
              echo "=========================="
              diffCount=0
              if [ -f "out/thumbs/$folder/$folder$imageIndex.png" ]; then
                diffCount=$(compare -metric ae -fuzz XX% "out/thumbs/$folder/$folder$imageIndex.png" compose_under.png null: 2>&1) 
                if [ "$diffCount" = 0 ]; then
                  needUpdateThumb[$imageIndex]=false
                else
                  mv compose_under.png "$path"
                  needUpdateThumb[$imageIndex]=true
                fi
              else
                mv compose_under.png "$path"
                needUpdateThumb[$imageIndex]=true
              fi
            fi
            fi
          fi
          if [ $(checkPatternOcurrence "$lineTitle" '\[video\]') = 1 ]; then
            customIndex=$((${customIndex}+1))
            videoId=$(echo "$lineTitle" | cut -c 26-$((${#lineTitle}-1)))
            fillSnippetVideo $videoId  
            description=$(jq '.['${imageIndex}-1'].description' "out/custom/$folder.json")
            adjustedIndex=$((${imageIndex}-1))
            isThumbUpdated=$(jq '.['$adjustedIndex'].updatedThumb // false' "out/custom/$folder.json")
            if [[ ! -z "$description" ]] && [ $descriptionLen -lt 10 ] || [ "$4" = "Y" ] || [[ $imageIndex -ge $startUpdateIndex ]] || [ $isThumbUpdated = false ]; then
              echo "isThumbUpdated: $isThumbUpdated"
              echo "$(jq '.['$adjustedIndex']' "out/custom/$folder.json")"
              if [ "${needUpdateThumb[$imageIndex]}" = true ] || [ $forceGenThumb = true ] || [ $genThumb = true ] || [ $isThumbUpdated = false ]; then
                  echo "==============.................."
                  echo "UPDATED THE THUMB $videoId $path"
                  echo "==============.................."
                  sendDataBinaryRequest "POST" "$urlBaseAPI/upload/youtube/v3/thumbnails/set?videoId=$videoId&uploadType=media" "Content-Type: image/jpeg" "@$path"
                  echo "$(jq '.['$adjustedIndex'].updatedThumb = true' "out/custom/$folder.json")" > "out/custom/$folder.json"
              fi
              tags=$(jq '.['${imageIndex}-1'].tags' "out/custom/$folder.json")
              echo "$(updateVideoPayload "$videoId" "$description" "$titleVideo" "28" "pt-BR" "pt-BR" "$tags")"
              sendResquestWithPayload "PUT" "$urlBaseAPI/youtube/v3/videos?part=snippet" "$(updateVideoPayload "$videoId" "$description" "$titleVideo" "28" "pt-BR" "pt-BR" "$tags")"
              for row in $(echo ${playlists} | jq -c '.[]' -r); do
                addToPlaylist "POST" $row $videoId
              done
            fi
          fi
      done < "out/titles/$folder.md"
    fi
  fi
done < videos.md
for (( f=0; f<${#folders[@]} ; f++ ))
do 
  rm -rf "${folders[$f]}"*
done
rm -rf titles
rm *.png*
rm out/*.
