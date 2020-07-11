# LOAD BALANCER IMPLEMENTED IN ERLANG

This is a load balancer implemented in Erlang for unmanaged clusters.

It consists of two parts: server and client.
To submit a job, use "send2queue.erl" from Bash.

To start a server, load "bvvq.erl" inside Erlang environment and start "s()".

Make sure that you have described your nodes in a resource file.

## Example

The next example is taken from "pi.sh" in this repository. The command line shows how to submit a job (any valid bash sequence) to the queueing server.

Compute number $\pi$ with the precision of 5000 digits. Pipe a script into `bc` to do the actual job.
Return standard output in ".out" file.
Return error output in ".err" file.
Submit the job to the "express" queue. Queues have different priorities that can be changed at any time.

The submission command returns a job descriptor so that it can be used to terminate it or question its status.


```
~/MyProg/ERLANG/send2queue.erl -q express -o pi$1.out -e pi$1.err echo '"scale=5000;a(1)*4"' \| bc -l
```
