#!/usr/bin/env python3
from math import sqrt
import math
import re
from datetime import datetime
import time
with open('x') as f:
    firstax = list(map(float, [l.strip() for l in f.readlines()]))
with open('z') as f:
    secondax = list(map(float, [l.strip() for l in f.readlines()]))
with open('time') as f:
    times = list(map(str, [l.strip() for l in f.readlines()]))
times.append(times[-1])
#ans = sqrt(29)
#print(ans)
intermediate_angles=[]
headings_threesixty=[]
headingslines=[]
timesdecimal=[]
timesdecimalfloats=[]
timesdelta=[]
file=open('headings','w')
for i in range(len(firstax)+1):
    timesdecimal.append('0'+re.sub(r'^.*?\.', '.', times[i]))
    timesdecimalfloats.append(float(timesdecimal[i]))


for i in range(len(firstax)):
    timesdelta.append(timesdecimalfloats[i+1]-timesdecimalfloats[i])
    timesdelta[i]=str(timesdelta[i])

    intermediate_angles.append(math.acos(secondax[i]/(sqrt(firstax[i]**2+secondax[i]**2)))*180/math.pi) #Where the magic happens
    headings_threesixty.append(abs(math.ceil(firstax[i])*360-round(intermediate_angles[i])))

    if headings_threesixty[i] == 360:
        headingslines.append('0000')

    elif headings_threesixty[i] == 450:# edgcase where firstax is -1 exactly
        headingslines.append('0090')

    elif headings_threesixty[i] == 0:
        headingslines.append('0000')
    else:
        digits = int(math.log10(headings_threesixty[i]))+1
        if digits == 1:
            appendage="000"+str(headings_threesixty[i])
            headingslines.append(appendage)
        elif digits ==2:
            appendage="00"+str(headings_threesixty[i])
            headingslines.append(appendage)
        elif digits ==3:
            appendage="0"+str(headings_threesixty[i])
            headingslines.append(appendage)

    file.writelines('file \''+headingslines[i]+'.png\'''\n'+'duration '+timesdelta[i]+'\n')

#convert = float(times)
file.writelines('duration 0')
file.close()
#print(startdive)

startdivetime = datetime.strptime(
        times[0], '%H:%M:%S.%f')
enddivetime = datetime.strptime(
        times[-2], '%H:%M:%S.%f')
delta=enddivetime-startdivetime
seconds=delta.total_seconds()
datapoints=len(firstax)
framerate=datapoints/seconds
print(framerate)

file=open('framerate','w')
#print(type(framerate))
file.writelines(str(framerate))
file.close
#print(enddive)
