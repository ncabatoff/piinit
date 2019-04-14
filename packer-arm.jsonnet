local lib = import 'packer.jsonnet';
local from = "/vagrant";
{
  builders: lib.build_pi(),
  provisioners:
    lib.prov_ssh(from, "pi") +
    lib.prov_aptinst(["supervisor", "iproute2", "curl", "procps"]) +
    lib.prov_dpkgarmel() +
    lib.prov_custompkgs(from+"/packages/", ["arm", "armv6", "armv7", "all"]) +
    lib.prov_aptinst([
       "./arm/consul.deb",
       "./arm/nomad.deb",
       "./armv7/node_exporter.deb ",
       "./all/node_exporter-supervisord.deb",
       "./all/consul-config-server.deb",
       "./all/consul-config-local.deb",
       "./all/consul-config-static-hostid.deb",
       "./all/nomad-config-server.deb",
       "./all/nomad-config-local.deb",
       "./armv6/process-exporter.deb",
       "./all/process-exporter-config.deb",
       "./armv6/script-exporter.deb",
       "./all/raspberrypi_exporter.deb",
    ])
}
