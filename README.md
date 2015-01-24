# About this crapID repo:
Experiments in TV speech-to-text ("craptioning") and simhash-ing text to "crapID" for matching TV clips!

# Craptions:
Using <a href="http://en.wikipedia.org/wiki/CMU_Sphinx#PocketSphinx">(Pocket)Sphinx</a> very basic speech-to-text package, we make poor quality captions, AKA Craptions, from archive.org TV show audio.

# crapID
Using standard ubuntu (unix) OS package "<a href="http://manpages.ubuntu.com/manpages/man1/simhash.1.html">simhash</a>", we take each Craptioned piece and hash the text to a ~288 byte hash file.  We call this "crapID".  We can use the same "simhash" program to compare two crapIDs and compute similarity (values [0..1] for similarity).


# Experiment inputs:
A group of volunteers found TV political ADs in the Philadelphia, PA region of US TV recordings and identified just over 8000 commercials.

# Experiment goal:
See if we can use the "crapID" of the ADs to search an entire day or week of shows to see if we can find *other* repeated ADs previously not found!


assuming avg news/nonnews show is ~2880 secs
Goal for EOY 2014:
For the week before 2014 election, all TV shows (*including* non-news).
  - compute crapIDs for every 10 seconds of show (dec2014)
  - compute crapIDs for every 60 seconds of show (jan2015)
  - match all 8,075 manually found political PHL ads to above, using simhash (dec2014)
  - match all manually found political PHL ads to above, using simhash (dec2014)

# <a href="http://mozfestartoftheweb.tumblr.com/">MozFest 2014</a> experiment:
  - N = 31 news shows
  - 10 second chunks
  - made 18K files (.txt + .hash)  (288 * N)
  - 15 hrs to run
  - ~82MB for the txt/hash files

# extended experiment -- full week before (Nov) 2014 US elections:
  - N = 1732 news and nonnews shows
  - 55x MORE SHOWS
  - (288 * N) => 288 * 1732 => ~500k (.txt) + ~500k (.hash) files
  - ==> ~4.5GG of txt/hash files
  - ==> ~34 days to run!!
  - ==> so use  4x threads to get ~8.5 day run (dec2014)
  - ==> so use 12x threads to get < 3  day run (jan2015)
