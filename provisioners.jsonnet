{
  prov_pi(from)::
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
      ],

  prov_wifi(from)::
      [
        {
          "type": "shell",
          "inline": [
            "test -z \"{{user `wifi_password`}}\" || wpa_passphrase \"{{user `wifi_name`}}\" \"{{user `wifi_password`}}\" | sed -e 's/#.*$//' -e '/^$/d' >> /etc/wpa_supplicant/wpa_supplicant.conf"
          ]
        },
      ],

  prov_aptinst(from)::
      [
        {
          "type": "shell",
          "inline": [
            "apt-get update -y; apt-get install -y dnsutils lsof strace git",
            "apt-get install -y sudo gettext-base procps",
            "touch /etc/rc.local",
          ]
        },
      ],

  prov_consul(from)::
      [
        {
          "type": "shell",
          "inline": [
            "cd /tmp && git clone https://github.com/ncabatoff/terraform-aws-consul",
            "bash -x /tmp/terraform-aws-consul/modules/install-consul/install-consul --version 1.4.2 --arch {{user `hasharch`}}",
            "test -z \"{{user `dnsmasq`}}\" || /tmp/terraform-aws-consul/modules/install-dnsmasq/install-dnsmasq"
          ]
        },
        {
          "type": "file",
          "source": from + "/init-consul",
          "destination": "/opt/consul/"
        },
        {
          "type": "shell",
          "inline": [
            "chmod 755 /opt/consul/init-consul",
            "sed -i -e '/^exit 0$/d' /etc/rc.local",
            "test -z \"{{user `consul`}}\" || echo '/opt/consul/init-consul {{user `consul`}} &' >> /etc/rc.local"
          ]
        },
      ],

  prov_nomad(from)::
      [
        {
          "type": "shell",
          "inline": [
            "cd /tmp && git clone https://github.com/ncabatoff/terraform-aws-nomad",
            "/tmp/terraform-aws-nomad/modules/install-nomad/install-nomad --version 0.8.7 --arch {{user `hasharch`}}",
          ]
        },
        {
          "type": "file",
          "source": from + "/init-nomad",
          "destination": "/opt/nomad/"
        },
        {
          "type": "shell",
          "inline": [
            "chmod 755 /opt/nomad/init-nomad",
            "sed -i -e '/^exit 0$/d' /etc/rc.local",
            "test -z \"{{user `nomad`}}\" || echo '/opt/nomad/init-nomad {{user `nomad`}} &' >> /etc/rc.local"
          ]
        },
      ],

  prov_node_exporter(from)::
      [
        {
          "type": "file",
          "source": from+"/node_exporter",
          "destination": "/tmp/"
        },
        {
          "type": "shell",
          "inline": [
            "/tmp/node_exporter/install-node_exporter/install-node_exporter --version 0.17.0 --arch {{user `promarch`}}"
          ]
        },
        {
          "type": "shell",
          "inline": [
            "sed -i -e '/^exit 0$/d' /etc/rc.local",
            "echo /opt/prometheus/bin/run-node_exporter >> /etc/rc.local"
          ]
        },
      ],

  prov_prometheus(from)::
      [
        {
          "type": "file",
          "source": from+"/prometheus",
          "destination": "/tmp/"
        },
        {
          "type": "shell",
          "inline": [
            "/tmp/prometheus/install-prometheus/install-prometheus --version 2.7.1 --arch {{user `promarch`}}"
          ]
        },
        {
          "type": "shell",
          "inline": [
            "NODE_EXPORTER_TARGETS=$(echo {{user `corehosts`}}|sed 's/\\(,\\|$\\)/:9100\\1/g') NOMAD_TARGETS=$(echo {{user `corehosts`}}|sed 's/\\(,\\|$\\)/:4646\\1/g') CONSUL_TARGETS=$(echo {{user `corehosts`}}|sed 's/\\(,\\|$\\)/:8500\\1/g') envsubst < /tmp/prometheus/prometheus.yml > /opt/prometheus/config/prometheus.yml",
            "sed -i -e '/^exit 0$/d' /etc/rc.local",
            "test -z \"{{user `prometheus`}}\" || echo /opt/prometheus/bin/run-prometheus >> /etc/rc.local"
          ]
        },
      ],

  prov_terraform(from)::
      [
        {
          "type": "shell",
          "inline": [
            "test -z \"{{user `terraform`}}\" || (curl -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.11/terraform_0.11.11_{{user `hasharch`}}.zip && unzip -d /usr/local/bin/ /tmp/terraform.zip)"
          ]
        }
      ],
}
