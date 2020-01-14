local lib = import 'packer.jsonnet';
{
  builders: [{
    type: "docker",
    image: "piinit/hashinode:latest",
    pull: false,
    commit: true,
    changes: [
      "EXPOSE 9100 8500 4646",
    ],
  }],
  "post-processors": [
    [
      {
        type: "docker-tag",
        repository: "piinit/hashinode-cn",
        tag: "latest"
      },
    ],
  ],
  provisioners:
    lib.prov_custompkgs("./packages/", ["all"]) +
    lib.prov_aptinst_noupdate([
       "./all/nomad-config-server.deb",
       "./all/nomad-config-local.deb",
       "./all/consul-config-server.deb",
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
            "supervisorctl stop nomad",
             "rm -rf /opt/nomad/data/*",
          ]
        },
      ],
}
