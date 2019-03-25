local lib = import 'packer.jsonnet';
local from = "/vagrant";
local defvars = {
  packages: "./arm/nomad.deb ./arm/consul.deb ./armv7/node_exporter.deb ./all/consul-server.deb ./all/consul-static-hostid.deb ./all/nomad-server.deb",
  consul_encrypt: "",
};
function(variables, coreips=["192.168.2.51", "192.168.2.52", "192.168.2.53"]) {
  "variables": std.mergePatch(defvars, variables),
  "sensitive-variables": ["wifi_password", "consul_encrypt"],
  builders: [{
    "type": "arm-image",
    "iso_url" : "file:///vagrant/2018-11-13-raspbian-stretch-lite.img",
    "iso_checksum_type":"sha256",
    "iso_checksum":"b9e22d7592c6936e4b0adadc9c9dbf7b4868cbfc26ff68a329e32f4af54fed70",
    "last_partition_extra_size" : 1073741824,
  }],
  provisioners:
    lib.prov_custompkgs("/vagrant/packages/", ["arm", "armv6", "armv7", "all"]) +
    lib.prov_aptinst(["supervisor", "iproute2", "curl", "procps"]) +
      [
        {
          "type": "shell",
          "inline": [ "dpkg --add-architecture armel" ],
        },
      ] +
    lib.prov_aptinst(["{{user `packages`}}"]) +
      [
        {
          "type": "shell",
          "inline": [
            "echo  >> /etc/ssh/ssh_config",
            "sed '/PasswordAuthentication/d' -i /etc/ssh/ssh_config",
            "echo 'PasswordAuthentication no' >> /etc/ssh/ssh_config",
            "echo localhost > /etc/hostname",
            "touch /boot/ssh",
            "mkdir -p -m 0700 /home/pi/.ssh",
          ]
        },
        {
          "type": "file",
          "source": from + "/authorized_keys",
          "destination": "/home/pi/.ssh/authorized_keys"
        },
        {
          "type": "shell",
          "inline": [
            "chmod 0600 /home/pi/.ssh/authorized_keys",
            "chown -R pi.pi /home/pi/.ssh",
          ]
        },
      ] +
    lib.prov_wifi() +
    lib.prov_consulclient(coreips) +
    ( if std.length(std.findSubstr('prometheus.deb', std.mergePatch(defvars, variables)['packages'])) > 0 then
        lib.prov_prometheus(coreips)
      else []
    )
}
