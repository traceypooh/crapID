# About this crapID repo:
Experiments in TV speech-to-text ("craptioning") and simhash-ing text to "crapID" for matching TV clips!

# Craptions:
Using <a href="http://en.wikipedia.org/wiki/CMU_Sphinx#PocketSphinx">(Pocket)Sphinx</a> very basic speech-to-text package, we make poor quality captions, AKA Craptions, from <a href="https://archive.org/tv">archive.org TV<a/> show audio.

# crapID
Using standard ubuntu (unix) OS package "<a href="http://manpages.ubuntu.com/manpages/man1/simhash.1.html">simhash</a>", we take each Craptioned piece and hash the text to a ~288 byte hash file.  We call this "crapID".  We can use the same "simhash" program to compare two crapIDs and compute similarity (values [0..1] for similarity).
I've modified the main C file a bit to make it 1000x faster for final matching.  (will make separate repo for that).


# Experiment inputs:
A group of volunteers found TV political ADs in the Philadelphia, PA region of US TV recordings and identified just over 8000 commercials.

# Experiment goal:
See if we can use the "crapID" of the ADs to search an entire day or week of shows to see if we can find *other* repeated ADs previously not found!

# Details

assuming avg news/nonnews show is ~2880 secs
Goal for EOY 2014:
For the week before 2014 election, all TV shows (*including* non-news).
  - compute crapIDs for every 10 seconds of show (dec2014) (experiment #1 below)
  - compute crapIDs for every 60 seconds of show (jan2015) (experiment #2 below)
  - match all 8,081 manually found political PHL ads to above, using simhash (dec2014)
  - match all 73 canonicalized political PHL ads to above, using simhash (dec2014)

# <a href="http://mozfestartoftheweb.tumblr.com/">MozFest 2014</a> small run hack experiment:
  - N = 31 news shows
  - 10 second chunks
  - made 18K files (.txt + .hash)  (288 * N)
  - 15 hrs to run
  - ~82MB for the txt/hash files

# extended experiment #1 (dec2014) -- full week before (Nov) 2014 US elections:
  - N = 1732 news and nonnews shows
  - 55x MORE SHOWS
  - (288 * N) => 288 * 1732 => ~500k (.txt) + ~500k (.hash) files
  - ==> ~4.5GG of txt/hash files
  - ==> ~34 days to run!!
  - ==> so use 4x threads to get ~8.5 days to process haystack
  - use seconds [10..20] in each AD as needle (10 seconds)
  - match ~500,000 haystack files  against  8081 canonical political ads (4B matches)


# extended experiment #2 (jan2015) -- full week before (Nov) 2014 US elections (like #1 above, but):
  - *60* second chunks in haystack videos
  - use 12x threads to get ~3 days to process haystack
  - use entire AD as needle (typically ~60 seconds)
  - match ~100,000 haystack files  against  ~73 canonical political ads (7.3M matches)


# RESULTS:
  - due to nature of "simhash", found all .txt "haystack" files with less than 50 words and removed them from consideration (all AD needles were 50+ words).  this helped avoid false positives.
  - reran matching
  - matching appears a bit spotty, but there are cases where it works great.
  - 27 of our 71 “canonical” ADs had matches.  using "ground truth" from our AD analysis team, only 31 of the ADs appeared to have been broadcast in the week we analyzed.  so 27 of 31 found 1+ match is encouraging.  all but 3 had *VERY* similar craptioned text between the AD and the #1 match, visually.  (sometimes the #1 match text was ~10-30 seconds in, since it’s perfect/even minutes we match against).  so it’s likely that most of the 24 of 27 top matches are correct, which is pretty stunning!
  - since we use "simhash" now to "de-dupe" our search results already at https://archive.org/tv (comparing search results to themselves, where we know all results already have usable captioning), we expect using existing captioning for either AD/needle or haystack will greatly improve results.  Further, where both comparators have usable captioning, we are confident the use of simhash to find duplicates already works very well in practice (basing that on the inverse in use now to dedupe).
  - Further, if we use a better "speech to text" system, we are certain to get even better results for uncaptioned pieces of TV clips.
  - This took about 1 day to think about, 1 day to plan/sort out how to use sphinx and the pieces, 1 day to prototype at MozFest, 1 day to extend to entire week before the 2014 election, 1 day to improve "simhash" to greatly speed up its capabilities.  So about 5 days over a few months.
  - We believe other people/teams could replicate these experiments quite easily (the main shell script is in this repo and is quite simple!)
  - We believe other approaches to "craptioning" or matching could be used/tried as well, for example audio waveform signatures or "fingerprinting" and an alternate comparator.
  - Given all the above, we have found this experimenting QUITE encouraging!
