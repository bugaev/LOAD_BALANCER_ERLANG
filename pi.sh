#!/bin/bash
submit_job()
{
	# For quick tests, long enough:
	~/MyProg/ERLANG/send2queue.erl -q express -o pi$1.out -e pi$1.err echo '"scale=5000;a(1)*4"' \| bc -l

	#~/MyProg/ERLANG/send2queue.erl -q $2 -o pi$1.out -e pi$1.err echo '"scale=20000;a(1)*4"' \| bc -l
}

ITER=200

cd tmp1
for i in $(seq 1 2 $ITER)
do
       	k=$i
       	echo $k
       	pwd
	submit_job $k p1
	echo
done
cd ..

cd tmp2
for i in $(seq 1 2 $ITER)
do
	k=$((i + 1))
       	echo $k
	pwd;
	submit_job $k p2
done
cd ..
