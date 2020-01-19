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
    lib.prov_aptinst(["iproute2 curl procps dnsutils vim-tiny net-tools"]) +
      [
        {
          type: "file",
          source: "/vagrant/provision-install-packages.sh",
          destination: "./",
        },
        {
          type: "shell",
          inline: [ "./provision-install-packages.sh ./amd64" ]
        },
      ],
}
