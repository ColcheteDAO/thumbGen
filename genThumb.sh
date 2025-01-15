magick -size 1280x720 xc:"rgba(27,33,44,1)" outfile.jpeg
magick image.jpeg -resize 870x510!  image.jpeg
magick composite -gravity southeast image.jpeg outfile.jpeg   compose_under.png
magick composite -gravity southwest man.png compose_under.png   compose_under.png
magick -pointsize 60 -gravity center -fill white -background "rgba(27,33,44,1)" -size 1280x210 -font 'Open-Sans-ExtraBold' label:'Adicionar imagem sudoeste #7' text.png
magick composite -gravity north text.png compose_under.png   compose_under.png
