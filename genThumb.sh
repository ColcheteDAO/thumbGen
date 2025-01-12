magick -define jpeg:size=320x320 public/image.jpeg \
      -thumbnail '320x320>' \
      -background black -gravity center -extent 320x320  outfile.gif
