local provisioner = import 'provisioners.jsonnet';
local from = "/vagrant";
{
  variables: {
    home: "{{env `HOME`}}",
    wifi_name: "",
    wifi_password: "",
    packages: "./arm/consul.deb",
  },
  "sensitive-variables": ["wifi_password"],
  builders: [{
    "type": "arm-image",
    "iso_url" : "file:///vagrant/2018-11-13-raspbian-stretch-lite.img",
    "iso_checksum_type":"sha256",
    "iso_checksum":"b9e22d7592c6936e4b0adadc9c9dbf7b4868cbfc26ff68a329e32f4af54fed70",
    "last_partition_extra_size" : 1073741824,
  }],
  provisioners:
    provisioner.prov_custompkgs("/vagrant/pkgbuilder/", ["arm", "armv6", "armv7", "all"]) +
    provisioner.prov_aptinst(["supervisor", "iproute2", "curl", "procps"]) +
    provisioner.prov_aptinst(["{{user `packages`}}"]) +
    provisioner.prov_pi(from) +
    provisioner.prov_wifi(from) +
    provisioner.prov_prometheus(["192.168.2.51", "192.168.2.52", "192.168.2.53"])
}
