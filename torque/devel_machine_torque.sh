#!/bin/sh
set -e

LOCALHOST=$1;
if [ "x$LOCALHOST" = "x" ]; then
    echo Must give the local machine\'s host name as an argument.  Example:
    echo
    echo '   ' sudo $0 banana
    echo
    exit 1;
fi;
if [ $LOCALHOST = "localhost" ]; then
    echo The local machine\'s name cannot be \'localhost\'.  Use another name, and make sure it is in your /etc/hosts as an alias for localhost.
    exit 1;
fi;

apt-get purge torque
rm -rf /var/spool/torque
apt-get install torque

cat <<EOF > /etc/default/torque
PBS_MOM=1
PBS_SCHED=1
PBS_SERVER=1

PBS_MOM_OPTS=''
PBS_SCHED_OPTS=''
PBS_SERVER_OPTS='-a t'
EOF

pbs_server -t create

echo $LOCALHOST > /var/spool/torque/server_name
echo $LOCALHOST > /var/spool/torque/server_priv/nodes
touch /var/spool/torque/sched_priv/sched_config
touch /var/spool/torque/sched_priv/dedicated_time
touch /var/spool/torque/sched_priv/holidays
touch /var/spool/torque/sched_priv/

/etc/init.d/torque restart;

qmgr -c "set server scheduling=true"
qmgr -c "create queue batch queue_type=execution"
qmgr -c "set queue batch started=true"
qmgr -c "set queue batch enabled=true"
qmgr -c "set queue batch resources_default.nodes=1"
qmgr -c "set queue batch resources_default.walltime=3600"
qmgr -c "set server default_queue=batch"


echo now to test, do:
echo 'echo sleep 20 | qsub; sleep 1; qstat'
echo and you should see the job in the qstat output.
