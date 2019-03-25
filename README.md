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

packer-arm.jsonnet doesn't care what hostnames are used, but it expects that the
three core servers will be on 192.168.2.{51,52,53}.  To change that
assumption modify arm-run.sh and add a --tla-code-file argument to jsonnet
as is done with the variables argument.

## Creating the image and writing it to the SD cards

Edit packer-arm.jsonnet if you want something other than Raspbian Stretch Lite.

## Build packages

If you didn't run `vagrant up` to create a virtual cluster first, there is an
extra step needed here:

```bash
go get -u github.com/ncabatoff/pkgbuilder
mkdir packages
cd packages
pkgbuilder
```

### Setup

To install jsonnet and create the VM used for building your Pi OS image:

```bash
cd $GOPATH/src/github.com/ncabatoff
git clone https://github.com/ncabatoff/packer-builder-arm-image
cd packer-builder-arm-image
path/to/piinit/checkout/arm-setup.sh
```

### Building

To create the OS image for your servers, run:

```bash
path/to/piinit/checkout/arm-run.sh
```

#### Customization

Optionally, there are a few settings that can be customized via a json (or jsonnet) file:

```json
{
  "consul_encrypt": "***",
  "wifi_name": "your_ssid",
  "wifi_password": "***",
  "packages": "./armv6/prometheus.deb ./armv6/node_exporter.deb ./arm/consul.deb ./all/prometheus-register-consul.deb ./all/consul-static-hostid.deb"
}
```

Then pass that as the sole argument to arm-run.sh, e.g.

```bash
path/to/piinit/checkout/arm-run.sh myvars.json
```

Note:
- Only provide settings you wish to override.
- If `wifi_name` is unspecified wifi won't be configured.  
- If `consul_encrypt` is specified it is an error to omit consul.deb from the package list.
- The default `packages` are suitable for building a core Consul/Nomad RPi server.

In addition to the three core Pi servers, I have a Pi Zero which I use
for monitoring via Prometheus.  I also run Terraform on it to schedule Nomad
jobs.

I use a file named zpivariables.json that looks like the above from which I build my
monitoring Pi Zero image, then derive the file for my core servers like this:

```
jq -r '{consul_encrypt: .consul_encrypt}' < zpivariables.json > pivariables.json
```

### Burning

You should use [Etcher](https://www.balena.io/etcher/) to write the image to
SD cards.  See `arm-burn.sh` for an example of how to invoke it non-interactively
from the command line.  Make sure to customize it according to your local setup.

## How it works

- [Packer](https://packer.io/) is used to create the OS images using
  - [packer-builder-arm-image](https://github.com/solo-io/packer-builder-arm-image) for ARM Pi images
  - built-in [Docker builder](https://www.packer.io/docs/builders/docker.html) for AMD64 Docker images
- [Jsonnet](https://jsonnet.org/) assembles the Packer config.
- [pkgbuilder](https://github.com/ncabatoff/pkgbuilder) creates custom .deb files using
  [go-getter](https://github.com/hashicorp/go-getter) and [nfpm](https://github.com/goreleaser/nfpm), from releases of
  - [Nomad](https://nomadproject.io)
  - [Consul](https://consul.io)
  - [Terraform](https://terraform.io)
  - [Prometheus](https://prometheus.io)
  - [node_exporter](https://github.com/prometheus/node_exporter)

## Motivation

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

## Dedicated cluster

You could certainly run other software on these servers as well.  For the volume
of data you're likely to have on your home setup, Consul and Nomad need very few
resources.  Personally I use a couple of NUCs to run everything, because I'd rather
have the core Consul/Nomad cluster as reliable and predictable as possible.

## TLS

Eventually I plan to add TLS (and probably Vault) to the mix.  For now the goal
is to get the simplest thing possible running smoothly.


