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
    lib.prov_custompkgs("./packages/", ["all"]) +
    lib.prov_aptinst(["./all/prometheus-register-consul.deb ./all/prometheus-local.deb ./all/consul-client.deb ./all/consul-local.deb ./all/node_exporter-supervisord.deb ./all/process-exporter-config.deb"]) +
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
