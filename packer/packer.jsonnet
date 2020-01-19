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
      iso_url : "file:///vagrant/stretch-minimal-rock64-0.8.3-1141-arm64.img",
      iso_checksum_type: "sha256",
      iso_checksum: "e7fb93309930c22c4cbd78d4aeb1341d0a36b16e9e6dae35f56c55d4b61c87e0",
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
  prov_aptinst_noupdate(pkgs):: [
    {
      type: "shell",
      inline: [
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
  prov_fstab_efi_ro():: [
    // Make sure that the boot device is mounted readonly
    {
      type: "shell",
      inline: [
        "perl -i -a -n -e '
          if ($F[0] == q(LABEL=boot)) {
            my %opts = map {$_, 1} split /,/, $F[3];
            $opts{ro} = 1;
            $F[3] = join q(,), keys %opts;
          }
          print qq(@F\n)' /etc/fstab"
      ],
    },
  ],
  prov_fstab_minio():: [
    // Make sure fstab entries exist for minio devices
    {
      type: "shell",
      inline: [
        "sed -i /^LABEL=minio/d /etc/fstab",
        "echo LABEL=minio1 /export1 ext4 nofail,auto,noatime 0 1 >> /etc/fstab",
        "echo LABEL=minio2 /export2 ext4 nofail,auto,noatime 0 1 >> /etc/fstab",
      ],
    },
  ],
}
