# piinit: initialize raspberry pi cluster

This repo contains code to build a cluster of servers running HashiCorp Nomad 
and Consul, monitored using Prometheus.

The primary target is low-power ARM single-board computers like the Raspberry Pi.
Docker is also supported for testing purposes.

Unlike most other non-cloud-based approaches for creating Consul clusters, we use 
"immutable" machine images.  A single OS image is used for every server in the
cluster, rather than running configuration software like Ansible to setup the
cluster.  In principle you could even abstain from installing SSH.

This immutable approach is nice for a variety of reasons, and a nice bonus is
that it saves time when building the SD cards for the Pi servers, since the
same image can be burned to every card.

## Hardware

Buy 3 ARM based systems, e.g. Raspberry Pi 3B+.  Buy 3 decent MicroSD cards, e.g.
Sandisk Extreme Pro, size is up to you.  You can use slower cards, but I would
skimp on size before speed.  Note that the Pi probably won't be able to use the
card at full speed, but it's still worth it for faster burn times.

If you don't already have a USB3 Micro SD card reader that supports higher-speed
card standards like UHS, get one, again to minimize burn time.

## Dependencies

To build Pi images: 
- [Vagrant](https://www.vagrantup.com/)
- Something to run virtual machines, e.g. VirtualBox.  

To build the Packer config: 
- [Jsonnet](https://jsonnet.org/) assembles the Packer config.

To build a Docker cluster:
- Docker
- [Go 1.11+](https://golang.org/dl/)
- [Packer](https://packer.io/)

## Docker cluster

Since it requires no extra hardware and takes only about a minute to setup, 
this is probably where you should begin.

Install Docker, Packer, Jsonnet, and Go 1.11+.  To build the image, run:

```bash
./docker.sh
```

To launch the cluster, run:

```bash
docker network create --subnet 192.168.2.0/24 --gateway 192.168.2.1 hashinet
for i in 1 2 3; do 
  docker run --rm -d --net hashinet --ip 192.168.2.2$i --name hashinode$i \
  -p 1909$i:9090 -p3850$i:8500 -p4646$i:4646 ncabatoff/hashinode:0.1;
done
```

After a few seconds you should be able to connect to http://localhost:19091/targets
to see the Prometheus view of the services coming up.

Go to http://localhost:38501/ui to see the Consul UI and http://localhost:46461/ui 
to see the Nomad UI.

To kill the cluster, run
```bash
docker kill hashinode{1,2,3}
```

## DNS and assigning hostnames

*Note: Consul handles DNS queries to perform DNS-based service discovery, but 
that's not what this section is about.*

In order to use a single OS image across all your cluster's servers, they need
to use DHCP to get their hostnames.  This means for each server, boot it up,
get its MAC address, and put that into your DHCP server (typically your router)
as a static DHCP entry with a fixed IP.  On subsequent boots it will set its
hostname based on that DHCP entry.

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


