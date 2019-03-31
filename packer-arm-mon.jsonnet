local lib = import 'packer.jsonnet';
local from = "/vagrant";
{
  builders: lib.build_arm(),
  provisioners:
    lib.prov_custompkgs(from+"/packages/", ["arm", "armv6", "all"]) +
    lib.prov_aptinst(["supervisor", "iproute2", "curl", "procps"]) +
    lib.prov_dpkgarm() +
    lib.prov_aptinst([
       "./arm/consul.deb",
       "./armv6/prometheus.deb",
       "./armv6/node_exporter.deb ",
       "./all/consul-local.deb",
       "./all/consul-static-hostid.deb",
       "./all/prometheus-register-consul.deb",
       "./all/prometheus-local.deb",
       "./all/wifi-local.deb",
       "./armv6/process-exporter.deb",
       // "./all/process-exporter-register-consul.deb",
       "./all/process-exporter-config.deb",
    ]) +
    lib.prov_pissh(from)
}
