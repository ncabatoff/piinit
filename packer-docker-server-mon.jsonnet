local provisioner = import 'provisioners.jsonnet';
{
  "variables": {
  },
  "builders": [{
    type: "docker",
    image: "ncabatoff/hashinode:latest",
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
        "type": "docker-tag",
        "repository": "ncabatoff/hashinode-mon",
        "tag": "latest",
      },
    ],
  ],
  provisioners:
    provisioner.prov_consulclient("/vagrant/consul-client-docker.hcl") +
    provisioner.prov_prometheus_register() +
    provisioner.prov_prometheus(["192.168.3.21", "192.168.3.22", "192.168.3.23"]) +
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
