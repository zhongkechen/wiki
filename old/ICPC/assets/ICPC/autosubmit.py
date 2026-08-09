import os.path
import glob
import urllib
import re
reobject = re.compile('(?P<hello>[0-9]*)\.(?P<ext>.*)')
for filename in glob.glob('[0-9]*.*'):
    mo = reobject.match(filename)
    if mo:
        prob, ext = mo.groups()
    else:
        continue
    if ext.lower() in ['c']:
        language = 0
    elif ext.lower() in ['cc', 'cpp']:
        language = 1
    else:
        continue
    params = urllib.urlencode({'language':language, 'user_id':'wzuacm',
        'passwd':'wzuacm', 'prob_id':prob, 'source':open(filename).read() })
    print params
    request = urllib.urlopen("http://acm.zju.edu.cn/submit_process.php", params)
    request.read()
    request.close()
