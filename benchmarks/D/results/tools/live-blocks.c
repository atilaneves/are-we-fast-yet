#define _GNU_SOURCE
#include <dlfcn.h>
#include <malloc.h>
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#define N (1<<21)
static void *keys[N]; static size_t vals[N]; static int dumped, in;
static void *(*rm)(size_t); static void (*rf)(void*); static void *(*rr)(void*,size_t); static void *(*rc)(size_t,size_t);
static size_t h(void*p){ return ((uintptr_t)p>>4)*2654435761u & (N-1); }
static void put(void*p,size_t n){ size_t i=h(p); while(keys[i]&&keys[i]!=p&&keys[i]!=(void*)1) i=(i+1)&(N-1); keys[i]=p; vals[i]=n; }
static void del(void*p){ size_t i=h(p); while(keys[i]){ if(keys[i]==p){ keys[i]=(void*)1; return;} i=(i+1)&(N-1);} }
static void dump(const char*why){ in=1; void*top=sbrk(0); fprintf(stderr,"--- %s: brk=%p\n",why,top); for(size_t i=0;i<N;i++) if(keys[i]&&keys[i]!=(void*)1) fprintf(stderr,"  live %p size=%zu  brk-%ld\n",keys[i],vals[i],(long)((char*)top-(char*)keys[i])); in=0; }
static void init(void){ rm=dlsym(RTLD_NEXT,"malloc"); rf=dlsym(RTLD_NEXT,"free"); rr=dlsym(RTLD_NEXT,"realloc"); rc=dlsym(RTLD_NEXT,"calloc"); }
void *malloc(size_t n){ if(!rm) init(); if(n==40 && !dumped && !in){ dumped=1; dump("before first tree malloc"); } void*p=rm(n); if(!in) put(p,n); return p; }
void free(void*p){ if(!rf) init(); if(!p) return; if(!in) del(p); rf(p); }
void *realloc(void*p,size_t n){ if(!rr) init(); if(p&&!in) del(p); void*q=rr(p,n); if(!in) put(q,n); return q; }
