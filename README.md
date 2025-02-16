
# Description

The fw.sh script configures the linux system to run as middlebox:
- Router (static routing)
- NAT (NAT1:1, multiple NAT1:n groups)
- Shaper (HTB + fq_codel) limiting bandwidth per computer or per group of computers
- DHCP server

It is optimized for large networks from several hundred to several thousand computers).
It is recommended to use a minimum 4-core processor.
It is recommended to use a 2 x 10Gbps ethernet cards (LAN and WAN) and separete one 1Gbps to management (MGMT)
Project documentation is available on the wiki at https://github.com/darton/fw/wiki
