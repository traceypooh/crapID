#!/bin/bash

# assuming avg news/nonnews show is ~2880 secs

# goal by 12/31:
# week before election, all shows (incl nonnews).
# compute crapIDs for every 10 seconds of show




# -----moz experiment:
# N = 31 news shows
# 10 second chunks
# made 18K files (.txt + .hash)  (288 * N)
# 15 hrs to run
# ~82M for the txt/hash files


# -----pre-election week:
# N = 1732 news and nonnews shows
# 55x MORE SHOWS
# (288 * N) => 288 * 1732 => ~500k (.txt) + ~500k (.hash) files
# ==> ~4.5G of txt/hash files
# ==> ~34 days to run!!
#
# ==> so use 4x threads to get ~8.5 day run


DIR=/var/tmp/tv;


source ~tracey/.aliases;
set -x;



sphinx(){
  LD_LIBRARY_PATH=/home/petabox/ptvn/trunk/library/usr/local/lib/  /home/petabox/ptvn/trunk/video_segmenter/speech_recognizer/pocketsphinx-example/pocketsphinx_example "$@";
}

sphinx-in-10s() {
  FI=${1:?"Usage: <input file, should be .wav>"};

  nsec=$(apackets "$FI" 2>/dev/null | egrep -o 'duration_time=[^ ]+'|cut -f2 -d= | perl -ne '$|=1; chop; $n+=$_; print (int($n*10)/10)."\n" if (eof());'|cut -f1 -d.);
  ID=$(echo "$FI" |perl -pe 's/\.wav$//');   
  echo "[$ID] [$nsec]";
  for i in $(seq -w 0 10 $nsec); do  
    ffmpeg -v 0 -y -ss $i  -i $FI -t 10  -vn -c:a copy  tmp.wav;
    sphinx -i tmp.wav -o $ID-$i.txt    >| $FI.sphinx.log   2>&1;
  done
}


speech-to-text(){
  fi="$1";
  stat $fi;
  lc $fi;

  for id in $(cat $fi); do
    # mp4 over mpg since we've already picked the proper audio stream
    SRC=$id.mp4;
    cd $DIR;

    if [ -e ABORT ]; then
      break;
    elif [ -d $id ]; then
      continue;
    fi
    mkdir -p $id;
    cd $id;

    # get entire mp4 and convert it to single WAV file
    rsy=$(finder -r $id)/$SRC;
    rsync  $rsy  $SRC;
    ffmpeg -v 0 -i $SRC  -ac 1  $id.wav;
    rm -f $SRC;

    # now cut the WAV in to 10-second chunks, and speech-to-text each
    sphinx-in-10s  $id.wav;
    rm -f $id.wav;
  done
  
  echo DONE $fi;
}


speech-to-text-ads(){
  cd $DIR/ADS/;
  for SRC in $(cat ADS); do

    # take mp4 and convert it to single WAV file
    ffmpeg -v 0 -i $SRC  -ac 1  $SRC.wav;

    # now cut the WAV in to 10-second chunks, and speech-to-text each
    sphinx-in-10s  $SRC.wav;
    rm -f $SRC.wav;
  done
  echo DONE;
}


textfiles-to-hash(){
  for txt in *txt; do
    if [ -e $txt.hash ]; then
      continue;
    fi

    # strip multiline w/ formatting output to just the text on a single line
    cat $txt |col 3- |perl -pe 's/\(\d+\)$//'  |egrep -v '^<s|sil|/s>$' |killspace |tr '\n' ' ' >| tmp.txt;  
    
    # now hash it (IFF we can!)
    # (use std pkg one because it will non-0 exit if cant hash txt (eg: no chars in input!))
    /usr/bin/simhash tmp.txt >| tmp.hash  &&  wc tmp.txt  &&  mv tmp.hash $txt.hash;
  done;
  rm -fv tmp.wav tmp.hash tmp.txt;
}


text-to-hash(){
  fi="$1";
  stat $fi;
  lc $fi;

  for id in $(cat $fi); do
    cd $DIR;

    if [ -e ABORT ]; then
      break;
    elif [ ! -d $id ]; then
      continue;
    fi
    cd $id;

    textfiles-to-hash;
  done
}


process(){
  fn="$1";
  cd $DIR;

  $fn xaa 2>&1 | tee $fn-xaa.log &
  $fn xab 2>&1 | tee $fn-xab.log &
  $fn xac 2>&1 | tee $fn-xac.log &
  $fn xad 2>&1 | tee $fn-xad.log &
  wait;
  wait;
  wait;
  wait;
  echo ALL KIDS DONE!
}




function match(){
  cd $DIR;
  php -- "$@" <<\
"EOF"
<? @spl_autoload(ia);
    $ads=glob("ADS/*-10.txt.hash");
    error_log("MATCHING AGAINST ADS, count: ".count($ads));
    
    $hashes = glob("*_*/*.hash");
    error_log("NUMBER POSSIBLE MATCHEES: ".count($hashes));
    
    foreach ($ads as $ad){
      $mat = "$ad.matches";
      if (file_exists($mat)) continue;

      Util::cmd("cat /var/tmp/tv/HASHES  |  /home/tracey/petabox/sw/lib/simhash/smash  -l $ad  |  sort -k1,1nr -o $mat");
    }
?>
EOF
}




#process "speech-to-text";
#speech-to-text-ads;

process "text-to-hash";

cd $DIR/ADS;  textfiles-to-hash;

cd $DIR;
find . -name '*.hash' |fgrep -v /ADS/ |sort -u -o HASHES;
match;
