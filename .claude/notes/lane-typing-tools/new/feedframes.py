# the frames around each line change in a recording: the text's box, a frame a line up to 60 frames
import subprocess, sys
from PIL import Image
src, out = sys.argv[1:3]
x, y, w, h = 660, 340, 620, 240   # (the text block, centred 79x38 window on 1920x1080: found below)
info = subprocess.run(['ffprobe','-v','error','-select_streams','v','-show_entries','stream=width,height','-of','csv=p=0',src],capture_output=True,text=True).stdout.strip()
W, H = map(int, info.split(','))
p = subprocess.Popen(['ffmpeg','-v','error','-i',src,'-fps_mode','passthrough','-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
frames = []
n = W*H*3
while True:
    b = p.stdout.read(n)
    if len(b) < n: break
    frames.append(b)
print(W, H, len(frames))
Image.frombytes('RGB',(W,H),frames[len(frames)//2]).save(out+'/mid.png')
# changed rows between frames in the middle of the screen
def box(b, x0, y0, x1, y1):
    return b''.join(b[(yy*W+x0)*3:(yy*W+x1)*3] for yy in range(y0,y1))
import pickle
pickle.dump((W,H,len(frames)), open(out+'/meta','wb'))
big = []
for i in range(1,len(frames)):
    a, c = frames[i-1], frames[i]
    d = sum(1 for k in range(0, n, 3*97) if a[k]!=c[k])
    big.append(d)
top = sorted(range(len(big)), key=lambda i:-big[i])[:24]
print('frames with most change:', sorted((i+1, big[i]) for i in top))
for i in sorted(top):
    Image.frombytes('RGB',(W,H),frames[i+1]).crop((640,100,1280,1000)).save(f'{out}/f{i+1:04d}.png')
