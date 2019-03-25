local lib = import 'packer.jsonnet';
local defvars = {
  consul_encrypt: "",
};
function(variables, coreips) {
  variables: std.mergePatch(defvars, variables),
  "sensitive-variables": ["consul_encrypt"],
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
    lib.prov_aptinst(["./all/nomad-server.deb ./all/consul-server.deb"]) +
    lib.prov_consulclient(coreips) +
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
