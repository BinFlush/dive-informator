#!/bin/bash

# One folder per dive
# 1. RUN PRESCRIPT
# 2. IMPORT RESULTING VIDEO INTO SUBSURFACE (YOU MIGHT HAVE TO TEMPORARILY ADJUST DIVETIME IN SUBSURFACE TO MATCH) AND EXPORT PNG + .ass FILE (as dykraw.ass)
# 3. OPEN PNG IN GIMP, CUT IT TO SIZE (no whitespace before and after dive) AND SET OPACITY TO 40%-50%. SAVE AS profile.png
# 4. SET ALIGNMENT VALUE TO 1 IN  .ass FILE
# 5. CHECK THAT SUBTITLES CONTAIN ENTIRE DIVE. TIMING CAN BE ADJUSTED IN SCRIPT.
# 5. BRÚKA TÍÐINAR Í SUBTITLES TIL AT JUSTERA TÍÐINAR Í HESUM SKRIPTINUM.
# 6. EFTIRKANNA ØLL VIRÐIR Í HESUM SKRIPTINUM, OG KOYR Á!!
N=4 #processes when multitasking
numvideo=numerals.mov
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
#offset=1 		#video offset "nær dykk byrjar" í sek (negativt virdi um dykk byrjar ádrenn video...)
#progbarlength=4 	# hvussu langt dykk er (í sekund) (tvs longd av video minus hvussu langt áðrenn videoend dykk steðgar) (plussa um kamera sløknar mitt í dykk) (minus offset >ja! tvs plussa um offset er negativt<)
resize=20 		#hvussu stór png skal vera í prosent av orig
kumpoffset=0		# hvussu langt kumpass skal offsettast í sekund "typiskt negativt virði"
################### First we need to concatinate all the seperate videofiles into one video
echo "Put all videofiles in this directory, named 1.MP4, 2.MP4 4.MP4 etc..."
echo
read -n 1 -s -r -p "Press any key to continue"
echo
if [ ! -f *.MP4 ]; then
    echo ".MP4 not found"
    exit 1
fi
origv=$(ls -1q *.MP4 | wc -l)

echo "vit hava $origv fílir"

echo -n "ffmpeg -i \"concat:" >> tmpconcatskript

for i in `seq $origv`; do  
  ffmpeg -i "$i".MP4 -c copy -bsf:v h264_mp4toannexb -f mpegts intermediate"$i".ts
  echo -n "intermediate$i.ts|" >> tmpconcatskript
done
sed -i 's/.$//' tmpconcatskript #delete trailing line
echo -n "\" -c copy -bsf:a aac_adtstoasc $vid" >> tmpconcatskript
. tmpconcatskript
rm tmpconcatskript
rm "intermediate*.ts"

echo
echo
echo
echo "$vid has been created."
echo
echo "Now use this video to generate diveprofile (save as $png)"
echo
echo "Also use Subsurface to export dive info as subtitles file (save as $sub)"
echo
echo "If you need compass bearings, you will need the headings file too (save as $head)"
echo
echo "Put this script away until ready, and come back when all files are present in this folder"
echo
echo
read -n 1 -s -r -p "Press any key to continue"
echo
echo
echo "are you double shure?"
echo
echo
read -n 1 -s -r -p "Press any key to continue"
echo


#################### HERE BE FUNCTIONS ###################



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
    if [ ! -f "$head" ]; then
        echo "$head not found"
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
    echo "ALL FILES EXIST. WISH ME LUCK!!"
    sleep 2
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
    progbarstick=25 #how much progbar sticks out
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
	filterstart=""
	filterinput="[0:v]"
    fi
}







function checksubs {
    echo "OK LAST CHECK UM SUBTITLES ER OK"
    sleep 4
    beg_seconds=$(grep -n "Dialogue:" $sub | awk -F  ":" '{print $3":"$4":"$5}' | head -n 1 | sed 's/[0-9],//1' |sed 's/,[0-9]//' | sed 's/\.00//' |
awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    ffmpeg -itsoffset -$beg_seconds -i $sub -c copy tmp.ass && mv tmp.ass $sub
    echo "1. Subs are zeroed:"
    sleep 1
    # Lets get the length of the dive in seconds
    progbarlength=$(grep -n "Dialogue:" $sub | awk -F  ":" '{print $3":"$4":"$5}' | tail -n 1 | sed 's/[0-9],//1' |sed 's/,[0-9]//' | sed 's/\.00//' | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    ffmpeg -itsoffset $offset -i $sub -c copy tmp.ass && mv tmp.ass $sub
    echo "2. Subs are offset $offset seconds"
    sleep 1
    while true
    do
      ffplay -vf subtitles=filename="$sub" "$vid"
      echo
      echo "Are subtitles correct?"
      echo "* enter to proceed"
      echo "* r to watch again"
      echo "* q to quit"
      echo "give number in sek (positive is right) ex. 1 or -3"
      read ans
    
      if [ -z "$ans" ]; then
        break
      elif [ "$ans" = "q" ]; then
        echo "exiting"
        exit 0
      else
          ffmpeg -itsoffset $ans -i $sub -c copy tmp.ass && mv tmp.ass $sub
      fi
    done
}
function checkcomp {
    echo "Check um kumpass ER OK"
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
      echo "Er compassið ok?"
      echo "* enter to proceed"
      echo "* r to watch again"
      echo "* q to quit"
      echo "* skriva 5 ella -5 fyri at flyta 5 til høgru ella vinstru"
      read ans
    
      if [ -z "$ans" ]; then
        break
      elif [ "$ans" = "q" ]; then
        echo "exiting"
        exit 0
      else
	  kumpoffset=$(($ans + $kumpoffset))
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
	[sub:v][1:v] overlay=W-w:H-h[0];color=c=red:s="$progw"x"$progh"[bar];\
	[0][bar]overlay=$videowith-$profilwith+($profilwith/($progbarlength))*(t-$offset):H-h:enable='between(t,$offset,$barslut)':shortest=1[manglarnal]\
	;color=c=white@0.5:s="$progw"x"112"[bartwo];\
	[manglarnal][bartwo]overlay=main_w/2-2:main_h-$progh+56:shortest=1[manglarnumerals];\
	[manglarnumerals][numerals]overlay=W/2-w/2:H-h-34:shortest=1" \
       	-pix_fmt yuv420p -c:a copy "$output_file"
}





function uttankump {
    ffmpeg -i "$vid" -i tmp.png -filter_complex \
	"[0:v]""$rgb""[tmp:v];\
	[tmp:v]subtitles="$sub"[sub:v];\
	[sub:v][1:v] overlay=W-w:H-h[0];color=c=red:s="$progw"x"$progh"[bar];\
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
    sleep 5
}


function buildkumpvideo {
    echo "building compass video "this might take a while""
    cp $head $compdir/$head
    echo "cd-ing to $compdir"
    cd $compdir
    ffmpeg -f concat -r 23.98 -i $head -c:v prores_ks -pix_fmt yuva444p10le "$heading_video" 
    mv "$heading_video" ../
    cd ..
}


function buildnumvideo {
    echo "building numeral video "this might take a while""
    cp $head $numdir/$head
    echo "cd-ing to $numdir"
    cd $numdir
    ffmpeg -f concat -r 23.98 -i $head -c:v prores_ks -pix_fmt yuva444p10le "$numvideo" 
    mv "$numvideo" ../
    cd ..
}




######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######
######### HERE SCRIPT STARTS! #######


echo "How many seconds in the video till dive starts? (negative if dive starts before video)"
read offset
echo
echo "Files needed: $vid, $png, $sub"
echo "If compassheadings are to be used: $head $heading_video (or $compdir or just $comp) AND $numvideo (or $numdir or simply $numsvg  ?"
echo
read mappa
cd "$mappa"
echo "going to $mappa"
echo
echo "skal hetta video inkludera compass "y/n""
read compassellaikki
if [ $compassellaikki = "y" ]; then
    echo "Brúkar compass"
        if [ -d "$compdir" ]; then
	    if [ $(ls $compdir/ | wc -l) -ge 360 ]; then
		echo "compassfílir eru har longu. Brúka tær "b" ella gera nýggjar "n"?"
		read neworold
		if [ $neworold = b ]; then
		    echo "brúkar gamlar"
		elif [ $neworold = n ]; then
		    build360
		else
		    echo "Invalid response"
		    echo "EXITING"
		    sleep 3
		    exit 1
		fi
	    else
		build360
	    fi
	else
	    mkdir $compdir
	    build360
	fi

    if [ -f "$heading_video" ]; then
	echo "$heading_video finnist longu brúka ella nýgga? (b/n)"
	read newold
	if [ $newold = b ]; then
	    echo "using old"
	elif [ $newold = n ]; then
	    buildkumpvideo
	else
	    echo "Invalid response"
	    echo "EXITING"
	    sleep 3
	    exit 1
	fi
    else
	buildkumpvideo
    fi
    

        if [ -d "$numdir" ]; then
	    if [ $(ls $numdir/ | wc -l) -ge 360 ]; then
		echo "numeralfílir eru har longu. Brúka tær "b" ella gera nýggjar "n"?"
		read neworold
		if [ $neworold = b ]; then
		    echo "brúkar gamlar"
		elif [ $neworold = n ]; then
		    build360numerals
		else
		    echo "Invalid response"
		    echo "EXITING"
		    sleep 3
		    exit 1
		fi
	    else
		build360numerals
	    fi
	else
	    mkdir $numdir
	    build360numerals
	fi

    if [ -f "$numvideo" ]; then
	echo "$numvideo finnist longu brúka ella nýgga? (b/n)"
	read newold
	if [ $newold = b ]; then
	    echo "using old"
	elif [ $newold = n ]; then
	    buildnumvideo
	else
	    echo "Invalid response"
	    echo "EXITING"
	    sleep 3
	    exit 1
	fi
    else
	buildnumvideo
    fi






    files_existvidkump
    checkcurves
    checkcomp
    checksubs
    convertpng
    countdown
    vidkump
else
    files_existuttankump
    checkcurves
    checksubs
    convertpng
    countdown
    uttankump
fi



