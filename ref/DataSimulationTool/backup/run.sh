#!/bin/bash

read -p "num worker:" numw
for ((i=1; i<=$numw; i++))
do	
	{
	 scriptname=$(printf 'simulate_signal(%d, %d)' "$i" "$numw")
         echo "run scipt: ~/Projects/Data/$scriptname"
    	 ~/Applications/MATLAB/R2023a/bin/matlab -nodesktop -nosplash -r "run ~/Projects/Data/$scriptname"
	}&
done
wait
