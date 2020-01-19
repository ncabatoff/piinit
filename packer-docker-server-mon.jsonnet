local lib = import 'packer.jsonnet';
{
  builders: [{
    type: "docker",
    image: "piinit/hashinode:latest",
    pull: false,
    commit: true,
    changes: [
      "ENTRYPOINT /usr/bin/supervisord --nodaemon",
      "EXPOSE 9100 9090",
    ],
  }],
  "post-processors": [
    [
      {
        type: "docker-tag",
        repository: "piinit/hashinode-mon",
        tag: "latest",
      },
    ],
  ],
  provisioners:
    lib.prov_custompkgs("./packages/", ["amd64"]) +
    lib.prov_custompkgs("./packages/vm/", ["all"]) +
    lib.prov_aptinst_noupdate([
       "./amd64/prometheus.deb",
       "./amd64/consul_exporter.deb",
       "./all/prometheus-config-local.deb",
       "./all/consul-config-client.deb",
       "./all/consul-config-local.deb",
       "./all/node_exporter-supervisord.deb",
       "./all/process-exporter-config.deb",
       "./all/raspberrypi_exporter.deb",
    ]) +
      [
        {
          type: "shell",
          inline: [
            "supervisorctl stop consul",
             "rm -rf /opt/consul/data/*",
          ]
        },
      ],
}
