/* 
 * 2012-2015 Tracey Jaquith extended "simhash.c" with some alternate cmd-line args and ways to run.
 * It hooks in to check for the extended cases via a one-line insert into "main()" of simhash.c
 *
 * To compile:  
 *   gcc -g -O4 -Wall -ansi -pedantic  heap.c hash.c crc32.c smash.c  -lm  -o smash
 */



/* What follows is INSANELY CUTE 8-)
 * I'm hijacking the "main()" method in simhash.c to call my "main_extra()" to do
 * any alternate invocation extensions *first*, then call the "main()" in simhash.c
 * otherwise (if no extended cmd-line usages are in effect).
 * run you clever girl
 */
void main_extra(int argc, char **argv); /*fwd decl*/
int main_orig  (int argc, char **argv); /*fwd decl*/
int main(int argc, char **argv) { main_extra(argc, argv); return main_orig(argc, argv); } /*new main()*/
#define main(a,b) (main_orig(a,b)) /*hijack main() in simhash.c*/
#include "simhash.c"





#include <errno.h>

#define MAX_MATRIX_ON_THE_FLY_STRINGS   100
#define MAX_FILENAME_LENGTH             10000
#define LIST_MATCH_HASHES_MIN_SCORE     0.1

typedef unsigned char myhash[516];



static int list_match_hashes(char *filename1) {
  hashinfo *hi1, *hi2;
  double scored;
  char name2[MAX_FILENAME_LENGTH+1];

  FILE *fin=stdin;

  hi1 = read_hashfile(filename1);
  fprintf(stderr, "[%s]\n", filename1);

  if (!hi1)
    return 1;

  while ((fgets(name2, MAX_FILENAME_LENGTH, fin))){
    name2[strlen(name2)-1]=0x0;/*chop newline*/
    hi2 = read_hashfile(name2);
    if (!hi2)
      continue;

    scored = score(hi1, hi2);
    if (scored < LIST_MATCH_HASHES_MIN_SCORE)
      continue;

    print_score(0, scored);
    printf("\t%s\n", name2);
    free_hashinfo(hi2);
  }

  free_hashinfo(hi1);
  return 0;
}




/* variation on default  "running_crc()"  */
static int onthefly_running_crc(FILE *f) {
    int i;
    static char *buf = 0;
    int nRead=0;
    if (buf == 0) {
      buf = malloc(nshingle);
      assert(buf);
    }
    for (i = 0; i < nshingle; i++) {
      int ch = fgetc(f);
      nRead++;
      if (ch == 0 || (nRead>1 && ch==EOF))
        return -1;
      if (ch == EOF)
        return 0;
      buf[i] = ch;
    }
    i = 0;
    while(1) {
      int ch;
      crc_insert((unsigned)hash_crc32(buf, i, nshingle));
      ch = fgetc(f);
      nRead++;
      
      if (ch == EOF  ||  ch == 0)
        return nRead;
      
      buf[i] = ch;
      i = (i + 1) % nshingle;
    }
    assert(0);
    /*NOTREACHED*/
}

    

static hashinfo *onthefly_read_stored_hash(myhash buff) {
    hashinfo *h = malloc(sizeof(hashinfo));
    short s;
    int i;
    unsigned short version;    
    int nbytes=0;
    assert(h);

    /* fread(&s, sizeof(short), 1, f);*/
    memcpy(&s, buff+nbytes, sizeof(short)); nbytes += sizeof(short);
    
    version = ntohs(s);
    if (version != FILE_VERSION) {
      fprintf(stderr, "bad file version: %d\n", version);
	return 0;
    }

    /* fread(&s, sizeof(short), 1, f);*/
    memcpy(&s, buff+nbytes, sizeof(short)); nbytes += sizeof(short);

    h->nshingle = ntohs(s);
    h->nfeature = 16;
    h->feature = malloc(h->nfeature * sizeof(int));
    assert(h->feature);
    i = 0;
    while(1) {
	int fe;
	
        /* int nread = fread(&fe, sizeof(int), 1, f); */
	int nread = sizeof(int);
        memcpy(&fe, buff+nbytes, nread); nbytes += nread;


	if (nbytes >= 515) {
	    h->nfeature = i;
	    h->feature = realloc(h->feature, h->nfeature * sizeof(int));
	    assert(h->feature);
	    return h;
	}
	if (i >= h->nfeature) {
	    h->nfeature *= 2;
	    h->feature = realloc(h->feature, h->nfeature * sizeof(int));
	    assert(h->feature);
	}
	h->feature[i++] = ntohl(fe);
    }
    abort();
    /*NOTREACHED*/
}




/* 
   alt matrix mode -- up to N strings in on stdin -- each string MUST end with '0' 
*/
int onthefly_matrix(int argc, char **argv) {
  
    int ret, nhash, *dupes;
    myhash hashes[MAX_MATRIX_ON_THE_FLY_STRINGS];
    double threshold=0.5;

    FILE *fin=stdin;
    
    if (argc>1)
      threshold = (double)atof(argv[1]);
    fprintf(stderr, "[Using dupe threshold >= %2.1f for comparisons]\n", threshold);

    dupes = calloc(MAX_MATRIX_ON_THE_FLY_STRINGS, sizeof(int));

    for (nhash=0; nhash < MAX_MATRIX_ON_THE_FLY_STRINGS; nhash++) {
      short s;
      int ptr=0;

      heap_reset(nfeature);
      hash_reset(nfeature);
      ret = onthefly_running_crc(fin);

      if (ret==0){
        fprintf(stderr, "READING DONE! %d hashes\n", nhash);
        break;
      }

      if (ret==-1){
        dupes[nhash]=1;
        fprintf(stderr, "read NOT ENOUGH chars .. string #%d processed, tossing out\n", nhash);
        continue;
      }
      fprintf(stderr, "read %10d chars .. string #%d processed, stashing hash\n", ret, nhash);
      

      /* adapted/hijacked from write_hash() */
      s = htons(FILE_VERSION);  /* file/CRC version */
      memcpy(&(hashes[nhash][ptr]), &s, sizeof(short));
      ptr += sizeof(short);
      
      s = htons(nshingle);
      memcpy(&(hashes[nhash][ptr]), &s, sizeof(short));
      ptr += sizeof(short);
      
      while (nheap > 0) {
        unsigned hv = htonl(heap_extract_max());
        ptr += sizeof(unsigned);
        memcpy(&(hashes[nhash][ptr]), &hv, sizeof(unsigned));
      }
    }
    {
      int idx1, idx2, smash_compared=0;
      double cmp;
      hashinfo *hi1, *hi2;
      
      for (idx1=0; idx1<nhash; idx1++){
        if (dupes[idx1]>0) continue; /*removed in prior compare (below)!*/
        
        for (idx2=idx1+1; idx2<nhash; idx2++){
          if (dupes[idx2]>0) continue; /*removed in prior compare (below)!*/
          
          smash_compared++;
          
          hi1 = onthefly_read_stored_hash(hashes[idx1]);
          hi2 = onthefly_read_stored_hash(hashes[idx2]);
          if (hi1->nshingle != hi2->nshingle) {
            fprintf(stderr, "shingle size mismatch\n");            
            exit(1);
          }
          cmp = score(hi1,hi2);
          fprintf(stderr, "%d vs %d => %4.2f\n", idx1, idx2, cmp);
          
          if (cmp >= threshold){
            dupes[idx2] = 1;
            printf("%d ", idx2);
          }
        }
      }
      
      printf("%d\n", smash_compared);
      return 0;
    }
}





void main_extra(int argc, char **argv) {

  /* if just one arg passed in, and it's a float,
   * we are doing "on the fly" matrix mode
   */
  
  if (argc==2){
    char *p = argv[1];
    errno = 0;
    strtod(argv[1], &p);
    if (errno == 0  &&  argv[1] != p  &&  *p == 0){
      /* arg is a float/double! */
      exit(onthefly_matrix(argc, argv));
    }
  }
  else if (argc==3){
    /* if args like "-l FILE" passed in,
     * then we are reading from STDIN a list of files to compare FILE against
     */
    if (strcmp(argv[1],"-l")==0)
      exit(list_match_hashes(argv[2]));
  }
}
