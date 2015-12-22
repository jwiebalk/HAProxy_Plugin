#!/bin/bash
printhelp(){
        #print help info and exit
        echo "Usage:makeha.sh [username] [app-id]"
        exit 1
}

if [[ $# -eq 0 ]];
 then
        printhelp
        exit 1
fi

curl -H"Content-Type:application/json"  -XPOST -d '{"event":"make-ha"}' -u "$1" -k https://{XXX.XXX.XXX}/broker/rest/application/$2/events
