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
    lib.prov_custompkgs("./packages/vm/", ["all"]) +
      [
        {
          type: "file",
          source: "/vagrant/provision/install-packages.sh",
          destination: "./",
        },
        {
          type: "shell",
          inline: [
            "./install-packages.sh '' ./all server",
            "supervisorctl stop consul",
             "rm -rf /opt/consul/data/*",
            "supervisorctl stop nomad",
             "rm -rf /opt/nomad/data/*",
          ]
        },
      ],
}
