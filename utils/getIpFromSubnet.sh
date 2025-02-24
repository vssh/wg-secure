#! /bin/bash


function getIpFromSubnet() {
   echo $(sed "s/\.[^.]*$/.$2/" <<< $1)
}

getIpFromSubnet $1 $2
