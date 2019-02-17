local provisioner = import 'provisioners.jsonnet';
local from = ".";
{
  "variables": {
    "home": "{{env `HOME`}}",
    "nomad": "",
    "consul": "client",
    "dnsmasq": "",
    "promarch": "linux-amd64",
    "hasharch": "linux_amd64",
    "prometheus": "",
    "corehosts": "",
    "coreips": "",
    "terraform": "",
  },
  "builders": [{
    type: "docker",
    image: "debian:stretch-slim",
    commit: true,
  }],
  "post-processors": [
    [
      {
        "type": "docker-tag",
        "repository": "ncabatoff/hashinode",
        "tag": "0.1"
      },
    ],
  ],
  provisioners: [
      {
          "type": "shell",
          "inline": [
            "ln /bin/true /bin/systemctl",
            "echo '/etc/init.d/supervisor start; bash /etc/rc.local' > /etc/start.sh",
            "chmod 755 /etc/start.sh",
          ]
      },
    ] +
    provisioner.prov_aptinst(from) +
    provisioner.prov_consul(from) +
    provisioner.prov_nomad(from) +
    provisioner.prov_node_exporter(from) +
    provisioner.prov_prometheus(from) +
    provisioner.prov_terraform(from),
}
