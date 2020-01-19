local lib = import 'packer.jsonnet';
local from = "/vagrant";
{
  builders: lib.build_pi(),
  provisioners:
    lib.prov_ssh(from, "pi") +
    lib.prov_aptinst(["supervisor", "iproute2", "curl", "procps", "less", "apt-transport-https", "gnupg"]) +
    lib.prov_dpkg_armel() +
    lib.prov_custompkgs(from+"/packages/", ["arm", "armv6", "all"]) +
    lib.prov_aptinst([
       "./arm/consul.deb",
       "./armv6/prometheus.deb",
       "./armv6/node_exporter.deb",
       "./all/node_exporter-supervisord.deb",
       "./all/consul-config-local.deb",
       "./all/consul-config-client.deb",
       "./all/consul-config-static-hostid.deb",
       "./all/prometheus-config-local.deb",
       "./all/wifi-local.deb",
       "./armv6/process-exporter.deb",
       "./all/process-exporter-config.deb",
       "./armv6/script-exporter.deb",
       "./all/raspberrypi_exporter.deb",
       "./armv6/consul_exporter.deb",
    ])
}
