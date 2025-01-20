convert -size 1280x720 xc:"rgba(27,33,44,1)" outfile.png
convert "$2".png -resize 870x510!  image.png
convert -composite -gravity southeast image.png outfile.png   compose_under.png
convert -composite -gravity southwest man.png compose_under.png   compose_under.png
convert -pointsize 60 -gravity center -fill white -background "rgba(27,33,44,1)" -size 1280x210 -font 'Open-Sans-ExtraBold' label:"$1" text.png
convert -composite -gravity north text.png compose_under.png   compose_under.png
