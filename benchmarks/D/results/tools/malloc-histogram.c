#define _GNU_SOURCE
#include <dlfcn.h>
#include <malloc.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
static void (*real_free)(void*);
static unsigned long hist_m[300], hist_f[300], shrinks, nm, nf;
static void *(*real_malloc)(size_t);
void *malloc(size_t n){ if(!real_malloc) real_malloc=dlsym(RTLD_NEXT,"malloc"); void*p=real_malloc(n); if(n<300) hist_m[n]++; nm++; return p; }
void free(void*p){ if(!real_free) real_free=dlsym(RTLD_NEXT,"free"); if(!p) return; size_t u=malloc_usable_size(p); void*b=sbrk(0); real_free(p); void*a=sbrk(0); nf++; if(a<b){ shrinks++; if(u<300) hist_f[u]++; } }
__attribute__((destructor)) static void dump(void){ fprintf(stderr,"mallocs=%lu frees=%lu shrinking-frees=%lu\nrequest sizes:",nm,nf,shrinks); for(int i=0;i<300;i++) if(hist_m[i]) fprintf(stderr," %d:%lu",i,hist_m[i]); fprintf(stderr,"\nusable size of shrinking frees:"); for(int i=0;i<300;i++) if(hist_f[i]) fprintf(stderr," %d:%lu",i,hist_f[i]); fprintf(stderr,"\n"); }
