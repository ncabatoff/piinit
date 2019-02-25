local provisioner = import 'provisioners.jsonnet';
{
  "variables": {
    coreips: "",
    packages: "./amd64/consul.deb ./amd64/nomad.deb ./amd64/node_exporter.deb ./amd64/prometheus.deb ./all/nomad-server.deb ./all/consul-server.deb",
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
    provisioner.prov_custompkgs("./packages/", ["amd64", "all"]) +
    provisioner.prov_aptinst(["supervisor", "iproute2", "curl", "procps", "dnsutils", "vim-tiny", "net-tools"]) +
    provisioner.prov_aptinst(["{{user `packages`}}"]) +
    provisioner.prov_consulclient("/vagrant/consul-client-docker.hcl") +
    provisioner.prov_prometheus(["192.168.3.21", "192.168.3.22", "192.168.3.23"]) +
      [
        {
          type: "shell",
          inline: [
            "supervisorctl stop consul",
             "rm -rf /opt/consul/data/*",
            "supervisorctl stop nomad",
             "rm -rf /opt/nomad/data/*",
          ]
        },
      ],
}
