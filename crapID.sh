#!/bin/bash

# assuming avg news/nonnews show is ~2880 secs

# Goal for EOY 2014:
#
# For the week before 2014 election, all TV shows (*including* non-news).
#   - compute crapIDs for every 10 seconds of show (dec2014)
#   - compute crapIDs for every 60 seconds of show (jan2015)
#   - match all 8,075 manually found political PHL ads to above, using simhash (dec2014)
#   - match all manually found political PHL ads to above, using simhash (dec2014)



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
# ==> so use  4x threads to get ~8.5 day run (dec2014)
# ==> so use 12x threads to get < 3  day run (jan2015)


DIR=/var/tmp/tv;
VIDEO_SPLIT_LENGTH=60; # cut up each full show into pieces of this many seconds
NPROC=12;
LOCAL_GIT_REPO=/home/tracey/crapID;   # local clone of https://github.com/traceypooh/crapID

source ~tracey/.aliases;
set -x;



sphinx(){
  LD_LIBRARY_PATH=/home/petabox/ptvn/trunk/library/usr/local/lib/  /home/petabox/ptvn/trunk/video_segmenter/speech_recognizer/pocketsphinx-example/pocketsphinx_example "$@";
}

sphinx-in-chunks() {
  FI=${1:?"Usage: <input file, should be .wav>"};

  # compute the number of seconds for the overall show (by analyzing the audio packets)
  nsec=$(apackets "$FI" 2>/dev/null | egrep -o 'duration_time=[^ ]+'|cut -f2 -d= | perl -ne '$|=1; chop; $n+=$_; print (int($n*10)/10)."\n" if (eof());'|cut -f1 -d.);
  ID=$(echo "$FI" |perl -pe 's/\.wav$//');   
  echo "[$ID] [$nsec]";
  # split the WAV into VIDEO_SPLIT_LENGTH chunks
  for i in $(seq -w 0 $VIDEO_SPLIT_LENGTH $nsec); do
    # make 1 chunk
    ffmpeg -v 0 -y -ss $i  -i $FI -t $VIDEO_SPLIT_LENGTH  -vn -c:a copy  tmp.wav;
    # now speech-to-text the chunk
    sphinx -i tmp.wav -o $ID-$i.txt    >| $FI.sphinx.log   2>&1;
  done
}


speech-to-text-haystack(){
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

    # now cut the WAV in to VIDEO_SPLIT_LENGTH second chunks, and speech-to-text each
    sphinx-in-chunks  $id.wav;
    rm -f $id.wav;
  done
  
  echo DONE $fi;
}


speech-to-text-ads(){
  cd $DIR/ADS/;

  fgrep _20  $LOCAL_GIT_REPO/IA_Philly_Media_Watch_IDENTIFIED_ADS_v1.2.csv |cut -f1-2 -d, |phpR 'list($uni,$url)=explode(",",$argn,2); if (!isset($map[$uni])) $map[$uni]=$url;' -E 'echo join("\n",array_values($map));' |cut -f5- -d/ |perl -pe 's=#start/=,=; s=/end/=,=' |sort -u -o ADS;
  
  for SRC in $(cat ADS); do
    if [ ! -e $SRC ]; then
      id=$(echo $SRC|cut -f1 -d,);
      start=$(echo $SRC|cut -f2 -d,);
      end=$(echo $SRC|cut -f3 -d,);
      wget -O $SRC  "http://archive.org/download/$id/$id.mp4?start=$start&end=$end&exact=1";
    fi

    
    # take mp4 and convert it to single WAV file
    ffmpeg -v 0 -i $SRC  -ac 1  $SRC.wav;

    # now cut the WAV in to VIDEO_SPLIT_LENGTH second chunks, and speech-to-text each
    sphinx-in-chunks  $SRC.wav;
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

  # split total number of items we will process into NPROC files
  ln -s $LOCAL_GIT_REPO/ids ids;
  cat ids | rand >| ids.rand;
  split -n l/$NPROC  ids.rand;


  # process each of the NPROC files as full unix process, with its own logfile
  for ids in x??; do 
    $fn $ids 2>&1 | tee $fn-$ids.log &
  done

  # now wait for all the processing to finish!
  for ids in x??; do 
    wait;
  done

  # move along, nothing to see here!
  echo ALL KIDS DONE!
}




function match(){
  cd $DIR;
  php -- "$@" <<\
"EOF"
<? @spl_autoload(ia);
    $ads=glob("ADS/*.txt.hash");
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




mkdir -p $DIR;
mkdir -p $DIR/ADS;
process "speech-to-text-haystack";
process "text-to-hash";
cd $DIR;

# throw out "haystack" files with < 50 words to avoid false positives
for i in $(find . -name ADS -prune -o -name '*.txt'|fgrep -v /ADS); do wc -l $i; done |phpR 'list($n,$fi)=explode(" ",$argn); if (is_numeric($n) && $n<50){ unlink("$fi.hash"); error_log($argn); }';
find . -name '*.hash' |fgrep -v /ADS/ |sort -u -o HASHES;


speech-to-text-ads;
process "text-to-hash";


cd $DIR/ADS;
textfiles-to-hash;
match;
