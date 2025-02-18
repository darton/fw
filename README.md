
# Description

The fw.sh script configures the Linux system to run as powerful middlebox:
- Router (static routing)
- NAT (NAT1:1, multiple NAT1:n groups)
- Shaper (HTB + fq_codel)
- DHCP server
- DNS resolver

It is optimized for large networks from several hundred to several thousand of computers.
It is recommended to use a minimum 4-core processor.
It is recommended to use a 2 x 10Gbps ethernet cards (LAN and WAN) and separete one 1Gbps to management (MGMT).
The configuration data for this script is supplied by a well-configured instance of [LMS](https://lms.org.pl), a system designed to support ISP operations.
Project documentation is available on the wiki at https://github.com/darton/fw/wiki.

