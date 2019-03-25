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
    lib.prov_aptinst(["./all/prometheus-register-consul.deb"]) +
    lib.prov_consulclient(coreips) +
    lib.prov_prometheus(coreips) +
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
