#!/usr/bin/env python3
from math import sqrt
import math
import re
from datetime import datetime
import time
with open('angles') as f:
    angles = list(map(float, [l.strip() for l in f.readlines()]))
with open('pitch') as f:
    pitch = list(map(float, [l.strip() for l in f.readlines()]))
with open('time') as f:
    times = list(map(str, [l.strip() for l in f.readlines()]))
times.append(times[-1])
#ans = sqrt(29)
#print(ans)
headings_threesixty=[]
headingslines=[]
headingslinesnum=[]
timesdecimal=[]
timesdecimalfloats=[]
timesdelta=[]

wronganglesindegrees=[]
oneifnegative=[]
filehead=open('headings','w')
filenum=open('headingsnum','w')
for i in range(len(angles)+1):
    timesdecimal.append('0'+re.sub(r'^.*?\.', '.', times[i]))
    timesdecimalfloats.append(float(timesdecimal[i]))


for i in range(len(angles)):
    if timesdecimalfloats[i] > timesdecimalfloats[i+1]: #fix duration times, when second flips over
        timesdelta.append(timesdecimalfloats[i+1]+1-timesdecimalfloats[i])
    else:
        timesdelta.append(timesdecimalfloats[i+1]-timesdecimalfloats[i])
    timesdelta[i]=str(timesdelta[i])

    wronganglesindegrees.append(angles[i]*180/math.pi) #Where the magic happens
    oneifnegative.append(abs(math.ceil(angles[i]/math.pi)-1))
    headings_threesixty.append(round(wronganglesindegrees[i]+(oneifnegative[i]*360)))

    if angles[i] == 0.00000 and abs(pitch[i]) > 1.252:
        if i == 0:
            headingslines.append('0000')
            headingslinesnum.append('TILT') # Stop rotation when compass tilts
        else:
            headingslines.append(headingslines[i-1]) # Stop rotation when compass tilts
            headingslinesnum.append('TILT') # Stop rotation when compass tilts
    else:

        if headings_threesixty[i] == 360:
            headingslines.append('0000')
            headingslinesnum.append('0000')
    
        elif headings_threesixty[i] == 450:# edgcase where firstax is -1 exactly
            headingslines.append('0090')
            headingslinesnum.append('0090')
    
        elif headings_threesixty[i] == 0:
            headingslines.append('0000')
            headingslinesnum.append('0000')
        else:
            digits = int(math.log10(headings_threesixty[i]))+1
            if digits == 1:
                appendage="000"+str(headings_threesixty[i])
                headingslines.append(appendage)
                headingslinesnum.append(appendage)
            elif digits ==2:
                appendage="00"+str(headings_threesixty[i])
                headingslines.append(appendage)
                headingslinesnum.append(appendage)
            elif digits ==3:
                appendage="0"+str(headings_threesixty[i])
                headingslines.append(appendage)
                headingslinesnum.append(appendage)

    filehead.writelines('file \''+headingslines[i]+'.png\'''\n'+'duration '+timesdelta[i]+'\n')
    filenum.writelines('file \''+headingslinesnum[i]+'.png\'''\n'+'duration '+timesdelta[i]+'\n')

#convert = float(times)
filehead.writelines('duration 0')
filenum.writelines('duration 0')
filehead.close()
filenum.close()
#print(startdive)

startdivetime = datetime.strptime(
        times[0], '%H:%M:%S.%f')
enddivetime = datetime.strptime(
        times[-2], '%H:%M:%S.%f')
delta=enddivetime-startdivetime
seconds=delta.total_seconds()
datapoints=len(angles)
framerate=datapoints/seconds
print(framerate)

file=open('framerate','w')
#print(type(framerate))
file.writelines(str(framerate))
file.close
#print(enddive)
