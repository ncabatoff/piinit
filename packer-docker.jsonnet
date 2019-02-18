local provisioner = import 'provisioners.jsonnet';
{
  "variables": {
    coreips: "",
    packages: "./amd64/consul.deb ./amd64/nomad.deb ./amd64/node_exporter.deb ./all/nomad-server.deb ./all/consul-client.deb ./all/consul-server.deb",
  },
  "builders": [{
    type: "docker",
    image: "debian:stretch-slim",
    commit: true,
    changes: [
      "ENTRYPOINT /usr/bin/supervisord --nodaemon",
      "EXPOSE 9100 9090 8500 4646",
    ],
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
  provisioners:
    provisioner.prov_makecustompkgs() +
    provisioner.prov_custompkgs("./pkgbuilder/", ["amd64", "all"]) +
    provisioner.prov_aptinst(["supervisor", "iproute2", "curl", "procps"]) +
    provisioner.prov_aptinst(["{{user `packages`}}"]) +
    provisioner.prov_prometheus(["192.168.2.21", "192.168.2.22", "192.168.2.23"])
}
