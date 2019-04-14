local lib = import 'packer.jsonnet';
local from = "/vagrant";
{
  builders: lib.build_rock64(),
  provisioners:
    lib.prov_ssh(from, "rock64") +
    lib.prov_sudonopass("rock64") +
    lib.prov_aptinst(["supervisor", "iproute2", "curl", "procps", "less", "apt-transport-https", "gnupg"]) +
    lib.prov_debian_docker() +
    lib.prov_custompkgs(from+"/packages/", ["arm64", "all"]) +
    lib.prov_aptinst([
       "./arm64/consul.deb",
       "./arm64/nomad.deb",
       "./arm64/node_exporter.deb",
       "./all/node_exporter-supervisord.deb",
       "./arm64/process-exporter.deb",
       "./all/process-exporter-config.deb",
       "./all/nomad-config-client.deb",
       "./all/nomad-config-local.deb",
       "./all/consul-config-client.deb",
       "./all/consul-config-local.deb",
       "./all/consul-config-static-hostid.deb",
    ])
}
