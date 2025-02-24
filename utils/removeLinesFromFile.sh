#! /bin/bash

function removeLinesFromFile() {
    local lines=$2
    if [[ $3 -gt $2 ]]; then
        lines="${lines},$3"
    fi
    lines="${lines}d"

    sed -i.bak -e "${lines}" "$1"
}

## params: filename, start, end(optional)
removeLinesFromFile $1 $2 $3
