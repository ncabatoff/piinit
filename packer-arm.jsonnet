local lib = import 'packer.jsonnet';
local from = "/vagrant";
{
  builders: lib.build_arm(),
  provisioners:
    lib.prov_custompkgs(from+"/packages/", ["arm", "armv6", "armv7", "all"]) +
    lib.prov_aptinst(["supervisor", "iproute2", "curl", "procps"]) +
    lib.prov_dpkgarm() +
    lib.prov_aptinst([
       "./arm/consul.deb",
       "./arm/nomad.deb",
       "./armv7/node_exporter.deb ",
       "./all/node_exporter-supervisord.deb",
       "./all/consul-server.deb",
       "./all/consul-local.deb",
       "./all/consul-static-hostid.deb",
       "./all/nomad-server.deb",
       "./armv6/process-exporter.deb",
       // "./all/process-exporter-register-consul.deb",
       "./all/process-exporter-config.deb",
    ]) +
    lib.prov_pissh(from)
}
