#!/bin/bash

for vfile in `grep -rl '<Event/>' *`
do 
 echo  $vfile
 vfile1=$vfile
 sed -e 's/<Event\/>//g' $vfile >$vfile.tmp
 mv $vfile.tmp $vfile
done 
