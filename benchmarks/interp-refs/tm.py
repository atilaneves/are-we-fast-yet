import subprocess,sys,time
r=[]
for i in range(3):
    s=time.time(); subprocess.run(sys.argv[1:],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); r.append(time.time()-s)
print(" ".join("%.3f"%x for x in r),"|"," ".join(sys.argv[1:]))
