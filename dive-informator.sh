#!/bin/bash

# One folder per dive
# 1. Put the partial videos into original-clips/ and start this script.
# 2. IMPORT RESULTING VIDEO INTO SUBSURFACE (YOU MIGHT HAVE TO TEMPORARILY ADJUST DIVETIME IN SUBSURFACE TO MATCH) AND EXPORT PNG + .ass FILE (as dykraw.ass)
# 3. OPEN PNG IN GIMP, CUT IT TO SIZE (no whitespace before and after dive) AND SET OPACITY TO 40%-50%. SAVE AS profile.png
# 4. CHECK THAT SUBTITLES CONTAIN ENTIRE DIVE. TIMING CAN BE ADJUSTED IN SCRIPT.

N=4 #processes when multitasking
numvideo=numerals.mov
origdir=original-clips
numsvg=numerals.svg
numdir=360numerals
comp=compass.svg ## Don't change this
compdir=360
sub=dykraw.ass
png=profile.png
vid=dykraw.mp4
output_file=dyk.mp4
head=headings
heading_video=prores.mov
py_data_translator=script.py
resize=20 		# size of png in percentage of original
kumpoffset=0		# how many seconds compass should be offset. Typically negative value, if AHRS started before video (edited in script)

################### First we need to concatinate all the seperate videofiles into one video




#################### HERE BE FUNCTIONS ###################
function concatinator {
while true
do
    
    echo "Put all videofiles in this directory: $origdir/"
    echo
    read -n 1 -s -r -p "Press any key to continue"
    echo
    origv=$(ls -1q "$origdir/" | wc -l)
    if [ $origv = 0 ]; then
        echo "No videos found"
    else
	break
    fi
done
sortedfiles=$(ls $origdir/ -cr --time=birth)
echo "there are $origv original files"

echo -n "ffmpeg -i \"concat:" >> tmpconcatskript

for i in $sortedfiles; do  
  ffmpeg -i "$origdir/$i" -c copy -bsf:v h264_mp4toannexb -f mpegts intermediate"$i".ts
  echo -n "intermediate$i.ts|" >> tmpconcatskript
done
sed -i 's/.$//' tmpconcatskript #delete trailing line
echo -n "\" -c copy -bsf:a aac_adtstoasc $vid" >> tmpconcatskript
. tmpconcatskript
rm tmpconcatskript
rm intermediate*.ts
echo
echo "$vid has been created."
}


#######PARRALELLIZATION
# initialize a semaphore with a given number of tokens
open_sem(){
    mkfifo pipe-$$
    exec 3<>pipe-$$
    rm pipe-$$
    local i=$1
    for((;i>0;i--)); do
        printf %s 000 >&3
    done
}

# run the given command asynchronously and pop/push tokens
run_with_lock(){
    local x
    # this read waits until there is something to read
    read -u 3 -n 3 x && ((0==x)) || exit $x
    (
     ( "$@"; )
    # push the return code of the command to the semaphore
    printf '%.3d' $? >&3
    )&
}
#######ENDPARRALELLIZATION



function files_existvidkump {
    if [ ! -f "$vid" ]; then
        echo "$vid not found"
        exit 1
    fi
    if [ ! -f "$sub" ]; then
        echo "$sub not found"
        exit 1
    fi
    if [ ! -f "$png" ]; then
        echo "$png not found"
        exit 1
    fi
    if [ ! -f "$heading_video" ]; then
        echo "$heading_video not found"
        exit 1
    fi
    if [ ! -f "$numvideo" ]; then
        echo "$numvideo not found"
        exit 1
    fi
}



function files_existuttankump {
    if [ ! -f "$vid" ]; then
        echo "$vid not found"
       exit 1
    fi
    if [ ! -f "$sub" ]; then
        echo "$sub not found"
        exit 1
    fi
    if [ ! -f "$png" ]; then
        echo "$png not found"
        exit 1
    fi
    echo "ALL FILES EXIST. WISH ME LUCK!!"
    sleep 2
}


function convertpng {
    echo "converting png"
    convert -resize "$resize"% "$png" tmp.png #resiza png
    
    videolength=$(ffprobe -i "$vid" -show_entries format=duration -v quiet -of csv="p=0")
    videowith=$(ffprobe -v error -hide_banner -select_streams v:0 -show_entries stream=width -of csv="p=0" "$vid")
    profilwith=$(identify -format "%w" tmp.png)
    profilheight=$(identify -format "%h" tmp.png)
    progbarstick=$(echo $profilheight | sed 's/.$//') #set overhang to roughly a thenth of height, by removing last digit
    if [ -z $progbarstick ]; then # set overlap to 0, in the weird case that the image heigth is single digits.
       progbarstick=0
    fi       
    progw=2 #progressbar with
    progh=$(($progbarstick + $profilheight))
    barslut=$(($offset + $progbarlength))
}





function checkcurves {
    echo "Do you wish to do color correction? (y/n)"
    read colorcorrect
    if [ "$colorcorrect" = "y" ]; then

        rgb="curves=green='0/0 0.5/0.1 1/0.5':blue='0/0 1/0.8':all='0/0 1/0.75',normalize=smoothing=72:independence=0.0"
        ans=unset
        echo "CHECK IF COLORS ARE GOOD"
        sleep 4
        while true
        do
          
          ffplay -vf "$rgb" "$vid"
          echo
          echo "rgb is - $rgb"
          echo "press enter to proceed if this is good, or make new value to test something else out"
          echo "q to quit"
          read "ans"
        
          if [ -z "$ans" ]; then
            break
            
          elif [ "$ans" = "q" ]; then
            echo "exiting"
            exit 0
        
          else
            rgb=$ans
            echo "new rgb command is:"
            echo "$rgb"
          fi
        done
	filterstart="[0:v]$rgb[rgbvid:v];"
	filterinput="[rgbvid:v]"
    elif [ "$colorcorrect" = "n" ]; then
	filterstart=
	filterinput="[0:v]"
    fi
}

function getprogbarlength {
    head_seconds=$(grep -n "Dialogue:" $sub | awk -F  ":" '{print $3":"$4":"$5}' | head -n 1 | sed 's/[0-9],//1' |sed 's/,[0-9]//' | sed 's/\.00//' | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    tail_seconds=$(grep -n "Dialogue:" $sub | awk -F  ":" '{print $3":"$4":"$5}' | tail -n 1 | sed 's/[0-9],//1' |sed 's/,[0-9]//' | sed 's/\.00//' | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    progbarlength=$(($tail_seconds-$head_seconds))
    echo
    echo "Dive duration is determined to be $progbarlength seconds (from subtitles data)"
    while true
    do
        echo "Press enter to accept, or write new value to manually change"
        read answer
        if [ -z $answer ]; then
	    echo "Dive duration accepted!"
	    sleep 2
	    break
	else
	    echo
            echo "New dive duration is $answer seconds (old was $progbarlength)"
            progbarlength=$answer
	fi
    done

}

function offsetsubs {
    beg_seconds=$(grep -n "Dialogue:" $sub | awk -F  ":" '{print $3":"$4":"$5}' | head -n 1 | sed 's/[0-9],//1' |sed 's/,[0-9]//' | sed 's/\.00//' | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    ffmpeg -itsoffset -$beg_seconds -i $sub -c copy tmp.ass && mv tmp.ass $sub
    echo "1. Subs are zeroed:"
    ffmpeg -itsoffset $offset -i $sub -c copy tmp.ass && mv tmp.ass $sub
}

function checkcomp {
    echo "Check if compas is OK and aligned"
    sleep 4
    
    while true
    do
      ffplay -f lavfi "movie='$vid':f=dshow[tmp0];\
	  movie='$heading_video'[tmp1];\
	  movie='$numvideo'[numerals];\
	  [numerals]setpts=PTS-STARTPTS+$kumpoffset/TB[numoffset];\
	  [tmp1]setpts=PTS-STARTPTS+$kumpoffset/TB[tmp2];\
	  [tmp0][tmp2]overlay=main_w/2-overlay_w/2:main_h-overlay_h:shortest=1[manglarnumerals];\
	  [manglarnumerals][numoffset]overlay=W/2-w/2:H-h-34:shortest=1"
      echo
      echo "Does the compass look good?"
      echo "* enter to proceed"
      echo "* r to watch again"
      echo "* q to quit"
      echo "* enter 5 or -5 to move 5 seconds left or right. You can  enter up to three decimals."
      read ans
    
      if [ -z "$ans" ]; then
        break
      elif [ "$ans" = "q" ]; then
        echo "exiting"
        exit 0
      else
	  kumpoffset=$(echo "$ans $kumpoffset" | awk '{print $1+$2}')
      fi
    done
}





function countdown {
    echo "letsgooooooO"
    echo "starting in:"
    sleep 1
    echo "5"
    sleep 1
    echo "4"
    sleep 1
    echo "3"
    sleep 1
    echo "2"
    sleep 1
    echo "1"
    sleep 1
    echo "GO"
}



function vidkump { 
    ffmpeg -i "$vid" -i tmp.png -i "$heading_video" -i "$numvideo" -filter_complex \
	"$filterstart\
	[2:v]setpts=PTS-STARTPTS+$kumpoffset/TB[ovr];\
	[3:v]setpts=PTS-STARTPTS+$kumpoffset/TB[numerals];\
	$filterinput[ovr]overlay=main_w/2-overlay_w/2:main_h-overlay_h:shortest=1[sammen:v];\
	[sammen:v]subtitles="$sub"[sub:v];\
	[sub:v][1:v]overlay=W-w:H-h[0];color=c=red:s="$progw"x"$progh"[bar];\
	[0][bar]overlay=$videowith-$profilwith+($profilwith/($progbarlength))*(t-$offset):H-h:enable='between(t,$offset,$barslut)':shortest=1[manglarnal]\
	;color=c=white@0.5:s="$progw"x"112"[bartwo];\
	[manglarnal][bartwo]overlay=main_w/2-2:main_h-$progh+56:shortest=1[manglarnumerals];\
	[manglarnumerals][numerals]overlay=W/2-w/2:H-h-34:shortest=1" \
       	-pix_fmt yuv420p -c:a copy "$output_file"
}


#	filterstart="[0:v]$rgb[rgbvid:v];"
#	filterinput="[rgbvid:v]"
#    elif [ "$colorcorrect" = "n" ]; then
#	filterstart=
#	filterinput="[0:v]"



function uttankump {
    ffmpeg -i "$vid" -i tmp.png -filter_complex \
	"$filterstart\
	$filterinput subtitles="$sub"[sub:v];\
	[sub:v][1:v]overlay=W-w:H-h[0];color=c=red:s="$progw"x"$progh"[bar];\
	[0][bar]overlay=$videowith-$profilwith+($profilwith/($progbarlength))*(t-$offset):H-h:enable='between(t,$offset,$barslut)':shortest=1" \
	-pix_fmt yuv420p -c:a copy "$output_file"
}



function build360 {
    if [ ! -f "$comp" ]; then
        echo "$comp not found"
        exit 1
    fi
    echo "Building 360 Compassbase"
    if [ $(ls $compdir/ | wc -l) -gt 1 ]; then
        echo "stuff in folder. removing"
	rm $compdir/*
    else
	echo "folder already empty"
    fi
    for i in {0000..0359}
    do
        mogrify -format png -background Transparent -rotate -$i -crop 330x330 compass.svg
        compfiles=$(find . -name "compass*.png" -printf '.' | wc -m)
    
        if [ $compfiles -gt 1 ]; then
            for j in $( eval echo {1..$(($compfiles-1))} )
            do
                rm "compass-${j}.png"
            done
    	    mv compass-0.png $compdir/${i}.png
        else
    	    mv compass.png $compdir/${i}.png
        fi
        mogrify -format png -background Transparent -chop 1x150 -gravity south $compdir/${i}.png
        echo "$i"
    done
    sha256sum $comp > $compdir/check
}

function build360numeralscore {
        cp numerals.svg $i.svg
        sed -i "s/TEKSTUR/$i/g" $i.svg
        mogrify -format png -background Transparent $i.svg
        mv $i.png "$numdir/0$i.png"
        rm $i.svg
        echo "numeral-$i"
    }

function build360numerals {
    if [ ! -f "$numsvg" ]; then
        echo "$numsvg not found"
        exit 1
    fi
    echo "Building 360 Compassbase"
    if [ $(ls $numdir/ | wc -l) -gt 1 ]; then
        echo "stuff in folder. removing"
	rm $numdir/*
    else
	echo "folder already empty"
    fi
    open_sem $N
    for i in {000..359}
    do
        run_with_lock build360numeralscore
    done
    sha256sum $numsvg > $numdir/check

    sleep 5
}


function buildkumpvideo {
    echo "building compass video "this might take a while""
    cp $head $compdir/$head
    echo "cd-ing to $compdir"
    cd $compdir
    while true
    do
        ffmpeg -y -f concat -i $head -c:v prores_ks -pix_fmt yuva444p10le "$heading_video" 
        if [ $? = 0 ]; then
            echo "success!!!!"
	    break
        else
            echo "render failed.. trying again!!"
        fi
    done    
    mv "$heading_video" ../
    cd ..
}


function buildnumvideo {
    echo "building numeral video "this might take a while""
    cp $head $numdir/$head
    echo "cd-ing to $numdir"
    cd $numdir
    while true
    do
        ffmpeg -y -f concat -r $framerate -i $head -c:v prores_ks -pix_fmt yuva444p10le "$numvideo" 
        if [ $? = 0 ]; then
	    echo "success!!!!"
	    break
        else
            echo "render failed.. trying again!!"
        fi
    done    
    mv "$numvideo" ../
    cd ..
}



function checkinputfiles {
    while true
    do
        missing=0
        missingfiles=""
        if [ ! -e $vid ]; then
            missingfiles+=\ $vid
            missing=1
        fi

        if [ ! -e $png ]; then
            missingfiles+=\ $png
            missing=1
        fi

        if [ ! -e $sub ]; then
            missingfiles+=\ $sub
            missing=1
        fi

        if [ $compassellaikki = "y" ]; then
            if [ ! -e $sub ]; then
                missingfiles+=\ $sub
                missing=1
            fi
        fi

        if [ $missing = 1 ]; then
            echo
	    echo "Files missing!:"
	    echo "$missingfiles"
	    read -n 1 -s -r -p "Add files and press any key to continue!"
        else
            break
        fi
    done
}


function checkoffset {
    sed -i '/^Style/s/[^,]*/8/3' $sub
    echo "Setting subtitles size to 8"
    if [ $compassellaikki = "y" ]; then
        sed -i '/^Style/s/[^,]*/1/19' $sub
	echo "Setting subtitle alignment to lower left"
	echo
	sleep 1
    else
        sed -i '/^Style/s/[^,]*/2/19' $sub
	echo "Setting subtitle alignment to lower center"
	echo
	sleep 1
    fi
    offset=0
    while true
    do
        offsetsubs
	echo
	echo
        echo "Offset is currently $offset."
        echo "How many seconds should it be moved (when does dive start) valid input is 5 or -5"
        echo "press w to watch video (with subtitles)"
        echo "Enter to confirm"
        echo "q to quit"
        echo
        read answer
        if [ "$answer" = "q" ]; then
            exit 1
        elif [ "$answer" = "w" ]; then
            ffplay -vf subtitles=filename="$sub" "$vid"
        elif [ -z "$answer" ]; then
            break
        else
            offset=$(($offset+$answer))
            echo
        fi
    done
}

function translate_log_data {
    awk -F "\"*,\"*" '{print $8}' data.txt > x
    awk -F "\"*,\"*" '{print $10}' data.txt > z
    awk -F "\"*,\"*" '{print $1}' data.txt > time
    ./$py_data_translator
    framerate=$(cat framerate)
    echo "framerate calculated to be $framerate fps"
    rm x z time framerate
}


function compassdialogue {
    # Remember to declare relevant variables before calling this function
    # dialoguedir
    # dialoguesvg
    # dialoguemov
    # buildvidcommand
    # buildpngcommand
    # crown_or_numerals
    if [ -f "$dialoguemov" ]; then
	echo "$dialoguemov already exists."
	echo "Use it? y/n"
	read usemov
	if [ $usemov = y ]; then
	    buildstatus=0 ## DONE
	    echo "setting buildstatus for $crown_or_numerals to 0"


	    
        elif [ $usemov = n ];then
	    if [ ! -d "$dialoguedir" ]; then
                mkdir $dialoguedir
		buildstatus=2
		echo "setting buildstatus for $crown_or_numerals to 2"
	    else
	        if [ $(ls $dialoguedir/*.png | wc -l) = 360 ]; then
                    echo "$(cat $dialoguedir/check)" | sha256sum --check --status 
                    if [ $? = 0 ]; then
			buildstatus=1
			echo "setting buildstatus for $crown_or_numerals to 1"
		    else
			echo "$crown_or_numerals file has changed"
			echo "Build new? y/n (might take a while)"
			read newfiles
			if [ $newfiles = y ]; then
			    buildstatus=2
			    echo "setting buildstatus for $crown_or_numerals to 2"
			elif [ $newfiles = n ]; then
			    buildstatus=1
			    echo "setting buildstatus for $crown_or_numerals to 1"
			fi
		    fi
		else
		    buildstatus=2
		    echo "setting buildstatus for $crown_or_numerals to 2"
	        fi
	    fi
	fi
    else
        if [ ! -d "$dialoguedir" ]; then
            mkdir $dialoguedir
            buildstatus=2
	    echo "setting buildstatus for $crown_or_numerals to 2"
	else
	    if [ $(ls $dialoguedir/*.png | wc -l) = 360 ]; then
                echo "$(cat $dialoguedir/check)" | sha256sum --check --status 
                if [ $? = 0 ]; then
		    buildstatus=1
		    echo "setting buildstatus for $crown_or_numerals to 1"
		else
		    echo "$crown_or_numerals file has changed"
		    echo "Build new? y/n (might take a while)"
		    read newfiles
		    if [ $newfiles = y ]; then
			echo "setting buildstatus for $crown_or_numerals to 2"
		        buildstatus=2
		    elif [ $newfiles = n ]; then
		        buildstatus=1
			echo "setting buildstatus for $crown_or_numerals to 1"
		    fi
		fi
	    else
		    buildstatus=2
		    echo "setting buildstatus for $crown_or_numerals to 2"
	    fi
	fi
    fi

    if [ $buildstatus -eq 0 ]; then
	echo "All is good. Doing nothing"
    elif [ $buildstatus -eq 1 ]; then
	echo "Building video"
        eval "${buildvidcommand}"
    elif [ $buildstatus -eq 2 ]; then
	eval "${buildpngcommand}"
        eval "${buildvidcommand}"
    fi

}

######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######
if [ -f $vid ]; then
    echo "$vid exists. Use it? y/n"
    while true
    do	
        echo
        read ans
        echo
        if [ $ans = y ]; then
	    break
	elif [ $ans = n ]; then
	    echo "Generating new!"
	    echo
	    concatinator
	    break
	else
	    echo "Invalid input!"
	fi
    done
else
    concatinator
fi
echo "Now use this video to generate diveprofile (save as $png)"
echo "Also use Subsurface to export dive info as subtitles file (save as $sub)"
echo "If you need compass bearings, you will need the headings file too (save as $head)"
echo "Put this script away until ready, and come back when all files are present in this folder"
echo
read -n 1 -s -r -p "Press any key to continue"
echo
echo "are you double shure?"
echo
read -n 1 -s -r -p "Press any key to continue"
echo

echo "Would you like to include a compass to this video? "y/n""
while true
do
    read compassellaikki
    if [ $compassellaikki != "y" ]; then
	if [ $compassellaikki != "n" ]; then
	    echo
	    echo "Invalid input"
	else
	    break
	fi
    else
	break
    fi
done
checkinputfiles
getprogbarlength
checkoffset
##debug
#if [ $compassellaikki = "y" ]; then
#    echo "$(cat $compdir/check)" | sha256sum --check --status 
#    if [ $? != 0 ]; then
#	  echo 'Compass svg has changed!'
#	  sleep 5
#	  exit 1
#    fi
#fi
#echo "Checksum valid"
#sleep 5
#exit 1
##debug done
if [ $compassellaikki = "y" ]; then
    echo "Using compass"
    ## checking compasscrown:
    dialoguedir=$compdir
    dialoguesvg=$comp
    dialoguemov=$heading_video
    buildvidcommand="translate_log_data; buildkumpvideo"
    buildpngcommand="build360"
    crown_or_numerals="compass crown"
    compassdialogue
    ## checking numerals
    dialoguedir=$numdir
    dialoguesvg=$numsvg
    dialoguemov=$numvideo
    buildvidcommand=" translate_log_data; buildnumvideo"
    buildpngcommand="build360numerals"
    crown_or_numerals="compass numerals"
    compassdialogue

    # dialoguedir
    # dialoguesvg
    # dialoguemov
    # buildvidcommand
    # buildpngcommand
    # crown_or_numerals



#    translate_log_data
#        if [ -d "$compdir" ]; then
#	    if [ $(ls $compdir/*.png | wc -l) = 360 ]; then
#                echo "$(cat $compdir/check)" | sha256sum --check --status 
#                if [ $? != 0 ]; then
#            	    echo 'Compass svg has changed!'
#		    echo "Build new compass pngs? y/n "this might take a while""
#		    read buildpngs
#		    if [ $buildpngs = "y" ]; then
#			build360
#	            fi
#		fi
#	    else
#		echo "all compass pngs not present!"
#		echo "building"
#		sleep 1
#		build360
#	    fi
#	else
#	    echo "compass directory does not exist"
#	    echo "building..."
#	    sleep 1
#	    mkdir $compdir
#	    build360
#	fi
#
#    if [ -f "$heading_video" ]; then
#	echo "$heading_video already exists. Use er New? (u/n)"
#	read newold
#	if [ $newold = u ]; then
#	    echo "using old"
#	elif [ $newold = n ]; then
#	    buildkumpvideo
#	else
#	    echo "Invalid response"
#	    echo "EXITING"
#	    sleep 3
#	    exit 1
#	fi
#    else
#	buildkumpvideo
#    fi
#    
#
#        if [ -d "$numdir" ]; then
#	    if [ $(ls $numdir/ | wc -l) -ge 360 ]; then
#		echo "Source numeral png files already exist. Use or New? (u/n)"
#		read neworold
#		if [ $neworold = u ]; then
#		    echo "using old"
#		elif [ $neworold = n ]; then
#		    build360numerals
#		else
#		    echo "Invalid response"
#		    echo "EXITING"
#		    sleep 3
#		    exit 1
#		fi
#	    else
#		build360numerals
#	    fi
#	else
#	    mkdir $numdir
#	    build360numerals
#	fi
#
#    if [ -f "$numvideo" ]; then
#	echo "$numvideo already exists. Use or New? (u/n)"
#	read newold
#	if [ $newold = u ]; then
#	    echo "using old"
#	elif [ $newold = n ]; then
#	    buildnumvideo
#	else
#	    echo "Invalid response"
#	    echo "EXITING"
#	    sleep 3
#	    exit 1
#	fi
#    else
#	buildnumvideo
#    fi





    if [ -f "$head" ]; then
	rm $head
    fi
    files_existvidkump
    checkcurves
    checkcomp
    convertpng
    countdown
    vidkump
else
    files_existuttankump
    checkcurves
    convertpng
    countdown
    uttankump
fi



