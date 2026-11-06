// tools/vkbd.c — one virtual keyboard that lives as long as its stdin, for headless runs of X11 programs (wtype's
// keyboard comes and goes with each key, and Xwayland never keeps up): "k NAME" a key, "c MODS NAME" with mods
// (1 shift, 4 ctrl, 8 alt, 64 logo), "t TEXT" letters.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include "vk-protocol.h"
static struct zwp_virtual_keyboard_manager_v1 *mgr; static struct wl_seat *seat;
static struct zwp_virtual_keyboard_v1 *kb; static struct xkb_keymap *km; static struct xkb_state *st;
static struct wl_display *dpy;
static uint32_t now_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
static void ga(void*d,struct wl_registry*r,uint32_t id,const char*i,uint32_t v){(void)d;
 if(!strcmp(i,zwp_virtual_keyboard_manager_v1_interface.name))mgr=wl_registry_bind(r,id,&zwp_virtual_keyboard_manager_v1_interface,1);
 else if(!strcmp(i,wl_seat_interface.name)&&!seat)seat=wl_registry_bind(r,id,&wl_seat_interface,v<5?v:5);}
static void gr(void*d,struct wl_registry*r,uint32_t id){(void)d;(void)r;(void)id;}
static const struct wl_registry_listener reg={ga,gr};
static int find(xkb_keysym_t ks,int *shift){
 for(xkb_keycode_t c=xkb_keymap_min_keycode(km);c<=xkb_keymap_max_keycode(km);c++){
  for(int l=0;l<2;l++){const xkb_keysym_t*s;int n=xkb_keymap_key_get_syms_by_level(km,c,0,l,&s);
   if(n==1&&s[0]==ks){*shift=l;return c;}}}
 return -1;}
static void tap(int code,uint32_t mods){
 zwp_virtual_keyboard_v1_modifiers(kb,mods,0,0,0);wl_display_roundtrip(dpy);usleep(25000);
 zwp_virtual_keyboard_v1_key(kb,now_ms(),code-8,1);wl_display_roundtrip(dpy);usleep(40000);
 zwp_virtual_keyboard_v1_key(kb,now_ms(),code-8,0);wl_display_roundtrip(dpy);usleep(25000);
 zwp_virtual_keyboard_v1_modifiers(kb,0,0,0,0);wl_display_roundtrip(dpy);usleep(25000);}
int main(void){dpy=wl_display_connect(NULL);if(!dpy)return 1;struct wl_registry*rg=wl_display_get_registry(dpy);
 wl_registry_add_listener(rg,&reg,NULL);wl_display_roundtrip(dpy);if(!mgr)return 1;
 kb=zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(mgr,seat);
 struct xkb_context*x=xkb_context_new(0);struct xkb_rule_names rn={0};rn.layout="us";km=xkb_keymap_new_from_names(x,&rn,0);
 char*s=xkb_keymap_get_as_string(km,XKB_KEYMAP_FORMAT_TEXT_V1);size_t n=strlen(s)+1;int fd=memfd_create("km",0);ftruncate(fd,n);
 void*p=mmap(0,n,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);memcpy(p,s,n);munmap(p,n);
 zwp_virtual_keyboard_v1_keymap(kb,WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1,fd,n);wl_display_roundtrip(dpy);
 char l[512];setvbuf(stdin,NULL,_IOLBF,0);
 while(fgets(l,sizeof l,stdin)){l[strcspn(l,"\n")]=0;int m=0,sh=0,c;char nm[128];
  if(l[0]=='k'&&sscanf(l,"k %127s",nm)==1){c=find(xkb_keysym_from_name(nm,0),&sh);if(c>0)tap(c,sh?1:0);else fprintf(stderr,"no key %s\n",nm);}
  else if(l[0]=='c'&&sscanf(l,"c %d %127s",&m,nm)==2){c=find(xkb_keysym_from_name(nm,0),&sh);if(c>0)tap(c,m|(sh?1:0));else fprintf(stderr,"no key %s\n",nm);}
  else if(l[0]=='t'&&l[1]==' '){for(char*q=l+2;*q;q++){c=find(xkb_utf32_to_keysym((unsigned char)*q),&sh);if(c>0)tap(c,sh?1:0);}}
 }
 return 0;}
