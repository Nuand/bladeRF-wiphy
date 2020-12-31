for i in */*/generate.sh; do echo "Running $i"; (cd `dirname $i`; sh generate.sh); done
