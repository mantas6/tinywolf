# tinywolf

Uses dnsmasq leases file to automatically map hostnames to hardware addresses.

Listens for HTTP requests with hostnames and sends WOL packets accordingly.

## Firewall setup

```
sudo firewall-cmd --zone=internal --add-port=5001/tcp --permanent
sudo firewall-cmd --reload
```
