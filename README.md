# piinit: initialize raspberry pi cluster

This repo contains code to build a cluster of servers running HashiCorp Nomad 
and Consul, monitored using Prometheus.

The primary target is low-power ARM single-board computers like the Raspberry Pi.
Docker is also supported for testing purposes.

Unlike most other non-cloud-based approaches for creating Consul clusters, we use 
a single "immutable" machine image shared by each of the nodes.  The OS
isn't modified after burning the image to SD card, except for the data
directories and logs written by the applications themselves.  This is in contrast 
to traditional provisioning/config mgmt solutions like Ansible or Chef.
In principle you could even abstain from installing SSH.

This immutable approach is nice for a variety of reasons, and a nice bonus is
that it saves time when initializing the Pi servers, since the image is built 
only once and then burned to every card.

# Test environment

To try out a virtual version of the cluster, install Virtualbox and Vagrant,
then run

```bash
vagrant up
```

This will create a VM containing all the dependencies, then build and run
docker images representing the core nomad/consul and prometheus servers.  It
will also setup nomad in client mode on the virtual machine and configure DNS
resolution to send queries for the .consul domain to the virtual cluster.

To test that everything is running, go to:

- [prometheus ui](http://localhost:49090/targets)
- [consul ui](http://localhost:48500/ui)
- [nomad ui](http://localhost:44646/ui)

Note that although the cluster will be restarted when the VM is rebooted, its
state will be wiped.  This is by design, though it's easy enough to add volume
mappings to provision-docker-launch.sh (and/or /etc/rc.local) if you'd rather 
the state be persisted.

# Real environment

Summary of steps:
0. Obtain ARM hardware
1. Create DNS entries for your RPi MAC addrs on your router
2. Build packages if you didn't run `vagrant up` above
3. Setup Packer ARM env
4. Build ARM OS images
5. Burn OS images to SD card

## Hardware

Buy 3 ARM based systems, e.g. Raspberry Pi 3B+.  Buy 3 decent MicroSD cards, e.g.
Sandisk Extreme Pro, size is up to you.  You can use slower cards, but I would
skimp on size before speed.  Note that the Pi probably won't be able to use the
card at full speed, but it's still worth it for faster burn times.

If you don't already have a USB3 Micro SD card reader that supports higher-speed
card standards like UHS, get one, again to minimize burn time.

## DNS and assigning hostnames

*Note: Consul handles DNS queries to perform DNS-based service discovery, but 
that's not what this section is about.*

In order to use a single OS image across all your cluster's servers, they need
to use DHCP to get their hostnames.  This means for each server, boot it up,
get its MAC address, and put that into your DHCP server (typically your router)
as a static DHCP entry with a fixed IP.  On subsequent boots it will set its
hostname based on that DHCP entry.

## Build packages

```bash
make packages
cd packages && ../pkgbuilder -arches all -config '{
  "ConsulSerfEncrypt": "S/OHRE9Nc4VmdGtJr11vBA==", 
  "CoreServers": ["192.168.2.51", "192.168.2.52", "192.168.2.53"],
  "WifiSsid": "YourSSID",
  "WifiPsk": "b71288ba03c9197d6afda9f1f67f913c12f41fb9e3585da18c11e68099355e62"
}'
```

Replace ConsulSerfEncrypt and CoreServers with your local values.

WifiSsid and WifiPsk are only needed if any of your systems need WiFi, in which 
case you should include the package wifi-local in their packer config.  Use the
wpa-supplicant command line tool to translate your WiFi password into PSK.

### Setup Packer ARM env

To create the VM used for building your Pi OS image:

```bash
mkdir -p $GOPATH/src/github.com/ncabatoff
cd $GOPATH/src/github.com/ncabatoff
git clone https://github.com/ncabatoff/packer-builder-arm-image
cd packer-builder-arm-image
path/to/piinit/checkout/arm-setup.sh
```

_Note: You may prefer to use the upstream repo I forked, https://github.com/solo-io/packer-builder-arm-image.
Be aware however that they seem to be using a bot that automatically merges PRs that merge cleanly, without 
doing any review.  This makes me uncomfortable enough that I'm not recommending it._

### Build ARM OS images

To create the OS image for your servers, run:

```bash
path/to/piinit/checkout/arm-run.sh
```

#### Customization

By default arm-run.sh will build an image based on packer-arm.json, which will serve
for your core Consul/Nomad servers.  

Given a single argument arm-run.sh will expect a .json file to give packer.  
Use packer-arm-mon.json to build a Prometheus server image that can be used on 
a Raspberry Pi Zero to monitor your cluster.  It includes a Consul client to 
discover all your services.

Given two arguments arm-run.sh will expect the first to be a .json file to 
overwrite, and the second to be a .jsonnet file used to build the former.
It will then give the .json file to packer to build an OS image with.

You need not use Jsonnet to build your own packer json files, but that's what I
use.

### Burning OS images to SD cards

You should use [Etcher](https://www.balena.io/etcher/) to write the image to
SD cards.  See `arm-burn.sh` for an example of how to invoke it non-interactively
from the command line.  Make sure to customize it according to your local setup.

## Notes

### How it works

- [Packer](https://packer.io/) is used to create the OS images using
  - [packer-builder-arm-image](https://github.com/solo-io/packer-builder-arm-image) for ARM Pi images
  - built-in [Docker builder](https://www.packer.io/docs/builders/docker.html) for AMD64 Docker images
- cmd/pkgbuilder creates custom .deb files using
  [go-getter](https://github.com/hashicorp/go-getter) and [nfpm](https://github.com/goreleaser/nfpm), from releases of
  - [Nomad](https://nomadproject.io)
  - [Consul](https://consul.io)
  - [Prometheus](https://prometheus.io)
  - [node_exporter](https://github.com/prometheus/node_exporter)

### Motivation

Many people have home servers, e.g. to serve media files.  But what about
redundancy?  You could setup a second server, but then how do you manage failover?
What if you want to run a cronjob regularly, and you don't care where it runs,
but you want to ensure it happens even if a server has gone down - and you'd 
prefer it didn't run on more than one server?

Rather than reinvent the wheel, it makes sense to use dedicated tools to do this.

Consul gives us reliable service discovery and a distributed KV.  Now you don't
have to refer to specific hosts, you can use DNS names that refer to services 
running whether the cluster has decided they should run.

Nomad gives us a way to run programs - servers and batch jobs - without having 
to specify where.

Both of these systems require three or more servers to provide redundancy and
avoid split brain inconsistency.  For a couple of hundred dollars you can buy
3 Raspberry Pis (or similar ARM-based single board computers) to run Nomad
and Consul.

### Dedicated cluster

You could certainly run other software on these servers as well.  For the volume
of data you're likely to have on your home setup, Consul and Nomad need very few
resources.  Personally I use a couple of NUCs to run everything else, because I'd 
rather have the core Consul/Nomad cluster as reliable and predictable as possible.

### TLS

Eventually I plan to add TLS (and probably Vault) to the mix.  For now the goal
is to get the simplest thing possible running smoothly.

### MacOS

To use Consul service discovery on your local MacOS machine:

- create a file /etc/resolver/consul containing the single line
```
nameserver 127.0.0.1
```
- brew install dnsmasq
- add these lines to /usr/local/etc/dnsmasq.conf:
```
server=/consul/192.168.2.51#8600
server=/consul/192.168.2.52#8600
server=/consul/192.168.2.53#8600
```
- sudo brew services start dnsmasq

The HashiCorp recommendation would be to run a local Consul agent, but the above
is sufficient and if I can avoid having another moving part to break I will.

NOTE: The Go resolver doesn't yet work properly on MacOS, so some Go binaries
(e.g. terraform) will not look in /etc/resolver/ to perform DNS name resolution.
A possible workaround if you want to run Terraform is to run it via docker so
that it effectively runs under Linux instead of MacOS, but when I tried this I 
ran into a conflict with my local network (192.268.2.0/24)
being used for another purpose in the Docker Desktop Hyperkit VM.  


