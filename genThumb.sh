magick -size 1280x720 -fill cyan -background none -pointsize 24 label:Hat   -gravity North outfile.jpeg
magick composite  image.jpeg outfile.jpeg   compose_under.png
