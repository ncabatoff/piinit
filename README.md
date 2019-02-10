# piinit: initialize raspberry pi cluster

This repo contains code to build a cluster of ARM servers running (principally)
HashiCorp Nomad and Consul.

Unlike most other approaches for creating on-prem Consul clusters, we use 
"immutable" machine images.  A single OS image is used for every server in the
cluster, rather than running configuration software like Ansible to setup the
cluster.  In principle you could even abstain from installing SSH.

## Hardware

Buy 3 ARM based systems, e.g. Raspberry Pi 3B+.  Buy 3 decent MicroSD cards, e.g.
Sandisk Extreme Pro, size is up to you.  You can use slower cards, but I would
skimp on size before speed.  Note that the Pi probably won't be able to use the
card at full speed, but it's still worth it for faster burn times.

If you don't already have a USB3 Micro SD card reader that supports higher-speed
card standards like UHS, get one, again to minimize burn time.

## Dependencies

[Vagrant](https://www.vagrantup.com/), along with something to run virtual
machines, e.g. VirtualBox.  

Everything else used by the scripts is downloaded as needed.

## DNS and assigning hostnames

*Note: Consul handles DNS queries to perform DNS-based service discovery, but 
that's not what this section is about.*

In order to use a single OS image across all your cluster's servers, they need
to use DHCP to get their hostnames.  This means for each server, boot it up,
get its MAC address, and put that into your DHCP server (typically your router)
as a static DHCP entry with a fixed IP.  On subsequent boots it will set its
hostname based on that DHCP entry.

## Creating the image and writing it to the SD cards

Edit packer.json if you want something other than Raspbian Stretch Lite.

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

## My setup

In addition to the three core Pi servers, I have a Pi Zero which I use
for monitoring via Prometheus.  I also run Terraform on it to schedule Nomad
jobs.

So I have `pivariables.json` which contains:

```
{
  "consul": "server",
  "nomad": "server",
  "promarch": "linux-armv7"
}
```

And also `zpivariables.json` which contains:

```
{
  "wifi_name": "***",
  "wifi_password": "***",
  "consul": "client",
  "dnsmasq": "true",
  "promarch": "linux-armv6",
  "prometheus": "true",
  "corehosts": "pi1,pi2,pi3",
  "terraform": "true"
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


