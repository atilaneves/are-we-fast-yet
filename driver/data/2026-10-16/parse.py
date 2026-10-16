import re,sys,glob,statistics as st
def get(f):
    for l in open(f):
        l=re.sub(r'\x1b\[[0-9;]*m','',l)
        if l.startswith('bytecode'):
            t=re.findall(r'([\d.]+) ms',l); return float(t[1]),float(t[4])
for d in ['corpus2','corpus3']:
  ps=sorted({re.sub(r'\.(before|after)\.\d\.txt','',g.split('/')[-1]) for g in glob.glob(f'/tmp/claude-1000/compare/{d}/*.txt') if 'status' not in g})
  for p in ps:
    r={}
    for v in('before','after'):
        x=[get(f'/tmp/claude-1000/compare/{d}/{p}.{v}.{i}.txt') for i in (1,2,3)]
        r[v]=(st.median(a[0] for a in x),st.median(a[1] for a in x),[a[0] for a in x],[a[1] for a in x])
    print(d,p,'run %.1f -> %.1f (%.3f)'%(r['before'][0],r['after'][0],r['after'][0]/r['before'][0]),'cmp %.1f -> %.1f (%.3f)'%(r['before'][1],r['after'][1],r['after'][1]/r['before'][1]),r['before'][2],r['after'][2])
