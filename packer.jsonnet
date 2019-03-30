{
  build_arm():: [
    {
      "type": "arm-image",
      "iso_url" : "file:///vagrant/2018-11-13-raspbian-stretch-lite.img",
      "iso_checksum_type":"sha256",
      "iso_checksum":"b9e22d7592c6936e4b0adadc9c9dbf7b4868cbfc26ff68a329e32f4af54fed70",
      "last_partition_extra_size" : 1073741824,
    }
  ],
  prov_dpkgarm():: [
    {
      "type": "shell",
      "inline": [ "dpkg --add-architecture armel" ],
    },
  ],
  prov_pissh(from):: [
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
  ],
  prov_aptinst(pkgs):: [
    {
      type: "shell",
      inline: [
        "apt-get update -y",
        "DEBIAN_FRONTEND=noninteractive apt-get install -y " + std.join(' ', pkgs),
      ]
    },
  ],
  prov_custompkgs(from, arches):: [
    {
      type: "file",
      generated: true,
      source: from+a,
      destination: a,
    } for a in arches
  ],
}
