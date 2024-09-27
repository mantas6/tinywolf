# tinywolf

Uses dnsmasq leases file to automatically map hostnames to hardware addresses.

Listens for HTTP requests with hostnames and sends WOL packets accordingly.

Example: GET `/wol/your-hostname`

## Dependencies

- `luarocks`
- `dnsmasq`
- `wakeonlan`

Installs as `systemd` user service.

Tested and ran on Debian 12.

## Firewall setup

```
sudo firewall-cmd --zone=internal --add-port=5001/tcp --permanent
sudo firewall-cmd --reload
```
