{
  build_pi():: [
    {
      "type": "arm-image",
      "iso_url" : "file:///vagrant/2018-11-13-raspbian-stretch-lite.img",
      "iso_checksum_type":"sha256",
      "iso_checksum":"b9e22d7592c6936e4b0adadc9c9dbf7b4868cbfc26ff68a329e32f4af54fed70",
      "last_partition_extra_size" : 1073741824,
    }
  ],
  build_rock64():: [
    {
      type: "arm-image",
      iso_url : "file:///vagrant/stretch-minimal-rock64-0.7.8-1061-arm64.img",
      iso_checksum_type: "sha256",
      iso_checksum: "07f0f370814ebfb51203f0d63d8ebdfaf669e9d8115933fb7beafbf1ec2817e5",
      qemu_binary: "qemu-aarch64-static",
      image_mounts: ["", "", "", "", "", "/boot", "/"],
      // "last_partition_extra_size" : 1073741824,
    }
  ],
  prov_dpkg_armel():: [
    {
      "type": "shell",
      "inline": [ "dpkg --add-architecture armel" ],
    },
  ],
  prov_debian_docker():: [
    {
      "type": "shell",
      "inline": [
        "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -",
        "sudo apt-key fingerprint 0EBFCD88",
        'sudo add-apt-repository    "deb [arch=arm64] https://download.docker.com/linux/debian
           $(lsb_release -cs)
           stable"',
      ],
    },
    {
      "type": "shell",
      inline: [
        "apt-get update -y",
        "DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io",
      ]
    },
  ],
  prov_ssh(from, user):: [
    {
      "type": "shell",
      "inline": [
        "echo  >> /etc/ssh/ssh_config",
        "sed '/PasswordAuthentication/d' -i /etc/ssh/ssh_config",
        "echo 'PasswordAuthentication no' >> /etc/ssh/ssh_config",
        "echo localhost > /etc/hostname",
        "touch /boot/ssh",
        "mkdir -p -m 0700 /home/" + user + "/.ssh",
      ]
    },
    {
      "type": "file",
      "source": from + "/authorized_keys",
      "destination": "/home/" + user + "/.ssh/authorized_keys"
    },
    {
      "type": "shell",
      "inline": [
        "chmod 0600 /home/" + user + "/.ssh/authorized_keys",
        "chown -R " + user + "." + user + " /home/" + user + "/.ssh",
      ]
    },
  ],
  prov_sudonopass(user):: [
    {
      type: "shell",
      inline: [ "echo '" + user + " ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/" + user ]
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
