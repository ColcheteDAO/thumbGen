magick -size 1280x720 -fill cyan -background none -pointsize 24 label:Hat   -gravity North outfile.jpeg
magick image.jpeg -resize 870x510!  image.jpeg
magick composite -gravity southeast image.jpeg outfile.jpeg   compose_under.png
magick composite -gravity southwest man.png compose_under.png   compose_under.png
