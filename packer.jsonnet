{
  // note that prov_consulclient must be called *after* packages are installed to
  // ensure that the consul user exists.  It's okay to call this even if not
  // planning to use consul, but to prevent leaving the encryption key around
  // needlessly it's designed to fail if the consul user doesn't exist but
  // the encryption key (user variable `consul_encrypt`) is nonempty.
  prov_consulclient(coreips)::
      [
        {
          type: "shell-local",
          inline: [
            "cat - > client.json <<EOF\n" + std.manifestJsonEx(
            {
                encrypt: "{{user `consul_encrypt`}}",
                retry_join: coreips,
            }, "  ") + "\nEOF\n"
          ],
        },
        {
          type: "shell",
          inline: ["mkdir -p /opt/consul/config/"]
        },
        {
          type: "file",
          generated: true,
          source: "client.json",
          destination: "/opt/consul/config/client.json",
        },
        {
          type: "shell",
          inline: ["if [ -n '{{user `consul_encrypt`}}' ]; then chown consul.consul /opt/consul/config/client.json; fi"]
        },
      ],

  prov_wifi()::
      [
        {
          type: "shell",
          inline: [
            "test -z \"{{user `wifi_password`}}\" || wpa_passphrase \"{{user `wifi_name`}}\" \"{{user `wifi_password`}}\" | sed -e 's/#.*$//' -e '/^$/d' >> /etc/wpa_supplicant/wpa_supplicant.conf"
          ]
        },
      ],

  prov_aptinst(pkgs)::
      [
        {
          type: "shell",
          inline: [
            "apt-get update -y; DEBIAN_FRONTEND=noninteractive apt-get install -y " + std.join(' ', pkgs)
          ]
        },
      ],

  prov_custompkgs(from, arches)::
      [{type: "file", generated: true, source: from+a, destination: a} for a in arches],

  prov_prometheus(hosts)::
      [
        {
          type: "shell-local",
          inline: [
            "cat - > prometheus.yml <<EOF\n" + std.manifestYamlDoc(
            {
              global: {
                scrape_interval: "15s",
              },

              scrape_configs: [
                {
                  job_name: "prometheus",
                  static_configs: [
                    {
                      targets: ['localhost:9090'],
                    },
                  ],
                },
                {
                  job_name: "node",
                  static_configs: [
                    {
                      targets: [h + ":9100" for h in hosts] + ['localhost:9100'],
                    },
                  ],
                },
                {
                  job_name: "consul-servers",
                  static_configs: [
                    {
                      targets: [h + ":8500" for h in hosts],
                    },
                  ],
                  metrics_path: "/v1/agent/metrics",
                  params: {
                    format: ["prometheus"],
                  },
                },
                {
                  job_name: "nomad-servers",
                  static_configs: [
                    {
                      targets: [h + ":4646" for h in hosts],
                    },
                  ],
                  metrics_path: "/v1/metrics",
                  params: {
                    format: ["prometheus"],
                  },
                },
                {
                  job_name: "consul-services",
                  consul_sd_configs: [
                    {
                      server: "localhost:8500",
                    },
                  ],
                  relabel_configs: [
                    {
                      source_labels: ["__meta_consul_tags"],
                      regex: ".*,prom,.*",
                      action: "keep",
                    },
                    {
                      source_labels: ["__meta_consul_service"],
                      target_label: "job",
                    },
                  ],
                },
                {
                  job_name: "nomad-clients",
                  consul_sd_configs: [
                    {
                      server: "localhost:8500",
                      services: ['nomad-client'],
                    },
                  ],
                  metrics_path: "/v1/metrics",
                  params: {
                    format: ["prometheus"],
                  },
                  relabel_configs: [
                    {
                      source_labels: ["__meta_consul_tags"],
                      regex: "(.*)http(.*)",
                      action: "keep",
                    },
                  ],
                },
              ],
            }) + "\nEOF\n"
          ]
        },
        {
          type: "shell",
          inline: ["mkdir -p /opt/prometheus/config/"],
        },
        {
          type: "file",
          generated: true,
          source: "prometheus.yml",
          destination: "/opt/prometheus/config/",
        },
        {
          type: "shell",
          inline: ["chown prometheus.prometheus /opt/prometheus/config/prometheus.yml"],
        },
      ],
}
