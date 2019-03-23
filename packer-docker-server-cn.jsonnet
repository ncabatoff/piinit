local provisioner = import 'provisioners.jsonnet';
{
  "variables": {
    packages: "./all/nomad-server.deb ./all/consul-server.deb",
  },
  "builders": [{
    type: "docker",
    image: "ncabatoff/hashinode:latest",
    pull: false,
    commit: true,
    changes: [
      "EXPOSE 9100 8500 4646",
    ],
  }],
  "post-processors": [
    [
      {
        "type": "docker-tag",
        "repository": "ncabatoff/hashinode-nc",
        "tag": "latest"
      },
    ],
  ],
  provisioners:
    provisioner.prov_custompkgs("./packages/", ["amd64", "all"]) +
    provisioner.prov_aptinst(["{{user `packages`}}"]) +
    provisioner.prov_consulclient("/vagrant/consul-client-docker.hcl") +
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
