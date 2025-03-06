ls
convert -size 1280x720 xc:"rgba(27,33,44,1)" outfile.png
convert "$2".png -resize 870x510!  image.png
convert -gravity southeast outfile.png image.png  -composite compose_under.png
convert -gravity southwest compose_under.png man.png -composite   compose_under.png
convert -pointsize 60 -gravity center -fill white -background "rgba(27,33,44,1)" -size 1280x210 -font 'Open-Sans-ExtraBold' label:"$1" text.png
convert -gravity north compose_under.png text.png -composite  compose_under.png
