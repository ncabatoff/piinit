local lib = import 'packer.jsonnet';
{
  builders: [{
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
        type: "docker-tag",
        repository: "piinit/hashinode",
        tag: "latest"
      },
    ],
  ],
  provisioners:
    lib.prov_custompkgs("./packages/", ["amd64"]) +
    lib.prov_aptinst(["supervisor iproute2 curl procps dnsutils vim-tiny net-tools"]) +
    lib.prov_aptinst(["./amd64/consul.deb ./amd64/nomad.deb ./amd64/node_exporter.deb ./amd64/prometheus.deb ./amd64/process-exporter.deb ./amd64/script-exporter.deb"])
}
