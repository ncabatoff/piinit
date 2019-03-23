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

To test that everything is running:

```bash
vagrant ssh
consul members
nomad server members
```

Note that although the cluster will be restarted when the VM is rebooted, its
state will be wiped.  This is by design, though it's easy enough to add volume
mappings to docker-launch.sh if you'd rather the state persisted.

# Real environment

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
assumption edit the file and modify the prov_prometheus() call.

## Creating the image and writing it to the SD cards

Edit packer-arm.jsonnet if you want something other than Raspbian Stretch Lite.

### Setup

To create the VM used for building your Pi OS image, run:

```bash
./setup.sh
```

### Building

To create the OS image for your servers, run:

```bash
./run.sh
```

Note that at the top of `packer.json` there are a bunch of variables.  You can
edit the script to change those.  Alternatively, you can provide them in a 
separate file, e.g.

```bash
VARSFILE=pivariables.json ./run.sh
```

### Burning

You should use [Etcher](https://www.balena.io/etcher/) to write the image to
SD cards.  See `burn.sh` for an example of how to invoke it non-interactively
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

## My setup

In addition to the three core Pi servers, I have a Pi Zero which I use
for monitoring via Prometheus.  I also run Terraform on it to schedule Nomad
jobs.

So I have `pivariables.json` which contains:

```
{
  "packages": "./arm/nomad.deb ./arm/consul.deb ./armv7/node_exporter.deb ./all/consul-server.deb ./all/consul-static-hostid.deb ./all/nomad-server.deb"
}
```

And also `zpivariables.json` which contains:

```
{
  "wifi_name": "***",
  "wifi_password": "***",
  "packages": "./arm/terraform.deb ./arm/consul.deb ./armv6/prometheus.deb ./armv6/node_exporter.deb ./all/consul-static-host-id.deb  ./all/consul-dnsmasq.deb"
}
```

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


