local provisioner = import 'provisioners.jsonnet';
{
  "variables": {
    coreips: "",
    packages: "./amd64/consul.deb ./amd64/nomad.deb ./amd64/node_exporter.deb ./amd64/prometheus.deb",
  },
  "builders": [{
    type: "docker",
    image: "debian:stretch-slim",
    commit: true,
    changes: [
      "ENTRYPOINT /usr/bin/supervisord --nodaemon",
      "EXPOSE 9100",
    ],
  }],
  "post-processors": [
    [
      {
        "type": "docker-tag",
        "repository": "ncabatoff/hashinode",
        "tag": "latest"
      },
    ],
  ],
  provisioners:
    provisioner.prov_custompkgs("./packages/", ["amd64", "all"]) +
    provisioner.prov_aptinst(["supervisor", "iproute2", "curl", "procps", "dnsutils", "vim-tiny", "net-tools"]) +
    provisioner.prov_aptinst(["{{user `packages`}}"])
}
