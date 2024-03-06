#!/bin/bash

read  -e -p "input the config file path:" filepath
read -p "input num worker:" numw

for ((i=1; i<=$numw; i++))
do	
	{
	 scriptname=$(printf 'generate(%d, %d, '"'"'%s'"'"')' $i $numw $filepath)
         echo "run scipt: $scriptname"
         LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6  
         /opt/matlab/R2017a/bin/matlab -nodesktop -nosplash -r "$scriptname"
	}&
done
wait
