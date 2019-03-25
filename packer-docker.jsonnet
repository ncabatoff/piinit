local lib = import 'packer.jsonnet';
local packages = "./amd64/consul.deb ./amd64/nomad.deb ./amd64/node_exporter.deb ./amd64/prometheus.deb";
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
    lib.prov_custompkgs("./packages/", ["amd64", "all"]) +
    lib.prov_aptinst(["supervisor iproute2 curl procps dnsutils vim-tiny net-tools"]) +
    lib.prov_aptinst([packages])
}
