package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/goreleaser/nfpm"
	_ "github.com/goreleaser/nfpm/deb"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

const (
	supervisorConfDir = "/etc/supervisor/conf.d"
	nomadWrapper      = `#!/bin/sh

myName=localhost
while [ "$myName" = "localhost" ]; do
  if [ -f /opt/nomad/config/server.hcl ] || [ -f /opt/nomad/config/client.hcl ]; then
    break
  fi
  myName=$(hostname -s)
  sleep 1
done
myIP=$(for i in $(hostname -i); do if echo $i | egrep -q '(::|^127)'; then :; else echo $i; fi; done)

cat - > /opt/nomad/config/advertise.hcl << EOF
advertise {
  http = "$myIP"
  rpc  = "$myIP"
  serf = "$myIP"
}
EOF

exec "$@"
`
	consulWrapper = `#!/bin/sh

myName=localhost
while [ "$myName" = "localhost" ] || [ ! -f /opt/consul/config/local.hcl ]; do
  myName=$(hostname -s)
  sleep 1
done
myIP=$(for i in $(hostname -i); do if echo $i | egrep -q '(::|^127)'; then :; else echo $i; fi; done)

exec "$@" -bind=$myIP -node=$myName
`
)

var recipes = []recipe{
	{
		Options{
			name:      "consul-local",
			depends:   []string{"consul"},
			configDir: "/opt/consul/config",
			rawConfigs: map[string]string{
				"local.hcl": `# Settings need by both server and client, but not generic
encrypt = "{{ .ConsulSerfEncrypt }}"
retry_join = {{ jsm .CoreServers }}
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:      "consul-server",
			depends:   []string{"consul"},
			configDir: "/opt/consul/config",
			rawConfigs: map[string]string{
				"server.hcl": `# Enable server mode
server = true
bootstrap_expect = 3
ui = true
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:      "consul-dnsmasq-localagent",
			depends:   []string{"consul", "dnsmasq"},
			configDir: "/etc/dnsmasq.d",
			rawConfigs: map[string]string{
				"10-consul": `# Enable forward lookup of the 'consul' domain:
server=/consul/127.0.0.1#8600
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:      "consul-static-hostid",
			depends:   []string{"consul"},
			configDir: "/opt/consul/config",
			rawConfigs: map[string]string{
				"static-host-id.hcl": `
disable_host_node_id = false  # must be true for docker, but desirable to have false for pi
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:              "consul",
			user:              "consul",
			version:           "1.4.4",
			upstreamURLFormat: "https://releases.hashicorp.com/consul/%s/consul_%s_linux_%s.zip",
			isDaemon:          true,
			args:              "agent",
			argData:           "-data-dir",
			argConf:           "-config-dir",
			wrapper:           consulWrapper,
			rawConfigs: map[string]string{
				"common.hcl": `log_level = "INFO"
client_addr = "0.0.0.0"
disable_update_check = true
enable_local_script_checks = true
telemetry {
  disable_hostname = true
  prometheus_retention_time = "10m"
}
`,
			},
		}, []string{"arm", "amd64"},
	},

	{
		// Register the consul agent as a "service" purely so that
		// Prometheus can discover all agents and scrape them.
		Options{
			name:      "consul-client",
			depends:   []string{"consul"},
			configDir: "/opt/consul/config",
			rawConfigs: map[string]string{
				"consul-client-service.json": `{
  "service": {
    "id": "consul-client",
    "name": "consul-client",
    "port": 8500
  }
}
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:      "nomad-client",
			depends:   []string{"nomad"},
			configDir: "/opt/nomad/config",
			rawConfigs: map[string]string{
				"client.hcl": `
client {
  enabled = true
  options {
    "docker.privileged.enabled" = true
  }
}
consul {
  address = "http://localhost:8500"
}
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:      "nomad-server",
			depends:   []string{"nomad"},
			configDir: "/opt/nomad/config",
			rawConfigs: map[string]string{
				"server.hcl": `server {
  enabled = true
  bootstrap_expect = 3
}
consul {
  address = "127.0.0.1:8500"
}
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:              "nomad",
			user:              "nomad",
			version:           "0.8.7",
			upstreamURLFormat: "https://releases.hashicorp.com/nomad/%s/nomad_%s_linux_%s.zip",
			isDaemon:          true,
			args:              "agent",
			argData:           "-data-dir",
			argConf:           "-config",
			wrapper:           nomadWrapper,
			rawConfigs: map[string]string{
				"common.hcl": `
telemetry {
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
}
disable_update_check = true
log_level = "INFO"
`,
			},
		}, []string{"arm", "amd64"},
	},

	{
		Options{
			name:                 "prometheus",
			user:                 "prometheus",
			version:              "2.7.1",
			upstreamURLFormat:    "https://github.com/prometheus/prometheus/releases/download/v%s/prometheus-%s.linux-%s.tar.gz",
			isDaemon:             true,
			argData:              "--storage.tsdb.path",
			argConf:              "--config.file",
			exporterRegisterPort: 9090,
			configFile:           "prometheus.yml",
		}, []string{"armv6", "amd64"},
	},

	{
		Options{
			name:       "prometheus-local",
			configFile: "prometheus.yml",
			configDir:  "/opt/prometheus/config",
			rawConfigs: map[string]string{
				"prometheus.yml": `---
global: 
  scrape_interval: "15s"

scrape_configs: 
- job_name: prometheus-local
  static_configs: 
  - targets: 
    - localhost:9090

- job_name: node_exporter-core
  static_configs: 
  - targets: 
    - localhost:9100
{{- range .CoreServers }}
    - {{ . }}:9100
{{- end }}

- job_name: process-exporter-core
  static_configs: 
  - targets: 
    - localhost:9256
{{- range .CoreServers }}
    - {{ . }}:9256
{{- end }}

- job_name: raspberrypi_exporter
  metrics_path: /metrics/raspberrypi_exporter
  static_configs: 
  - targets: 
    - localhost:9661
{{- range .CoreServers }}
    - {{ . }}:9100
{{- end }}

- job_name: consul-servers
  metrics_path: /v1/agent/metrics
  params: 
    format: 
    - prometheus
  static_configs: 
  - targets: 
{{- range .CoreServers }}
    - {{ . }}:8500
{{- end }}
  # See https://github.com/hashicorp/consul/issues/4450
  metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'consul_raft_replication_(appendEntries_rpc|appendEntries_logs|heartbeat|installSnapshot)_((\w){36})((_sum)|(_count))?'
    target_label: raft_id
    replacement: '${2}'
  - source_labels: [__name__]
    regex: 'consul_raft_replication_(appendEntries_rpc|appendEntries_logs|heartbeat|installSnapshot)_((\w){36})((_sum)|(_count))?'
    target_label: __name__
    replacement: 'consul_raft_replication_${1}${4}'

- job_name: nomad-servers
  metrics_path: /v1/metrics
  params: 
    format: 
    - prometheus
  static_configs: 
  - targets: 
{{- range .CoreServers }}
    - {{ . }}:4646
{{- end }}
  metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'nomad_raft_replication_(appendEntries_rpc|appendEntries_logs|heartbeat)_([^:]+:\d+)(_sum|_count)?'
    target_label: peer_instance
    replacement: '${2}'
  - source_labels: [__name__]
    regex: 'nomad_raft_replication_(appendEntries_rpc|appendEntries_logs|heartbeat)_([^:]+:\d+)(_sum|_count)?'
    target_label: __name__
    replacement: 'nomad_raft_replication_${1}${3}'

- job_name: consul-services
  consul_sd_configs: 
  - server: localhost:8500
  relabel_configs: 
  - action: keep
    regex: .*,prom,.*
    source_labels: 
    - __meta_consul_tags
  - source_labels:
    - __meta_consul_service
    target_label: job
  - source_labels:
    - __meta_consul_service
    target_label: job
    # Consul won't let us register names with underscores, but dashboards may
    # assume the name node_exporter.  Fix on ingestion.
    regex: node-exporter
    replacement: node_exporter

- job_name: nomad-clients
  consul_sd_configs: 
  - server: localhost:8500
    services: 
    - nomad-client
  metrics_path: /v1/metrics
  params: 
    format: 
    - prometheus
  relabel_configs: 
  - action: keep
    regex: (.*)http(.*)
    source_labels: 
    - __meta_consul_tags

- job_name: consul-clients
  consul_sd_configs: 
  - server: localhost:8500
    services: 
    - consul-client
  metrics_path: /v1/agent/metrics
  params: 
    format: 
    - prometheus
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name: "prometheus-register-consul",
		}, []string{"all"},
	},

	{
		Options{
			name:              "node_exporter",
			user:              "root",
			version:           "0.17.0",
			upstreamURLFormat: "https://github.com/prometheus/node_exporter/releases/download/v%s/node_exporter-%s.linux-%s.tar.gz",
			isDaemon:          true,
			args:              "--collector.supervisord --collector.wifi --no-collector.nfs --no-collector.nfsd",
			argConf:           "--collector.textfile.directory",
		}, []string{"armv6", "armv7", "amd64"},
	},

	{
		Options{
			name:      "node_exporter-supervisord",
			configDir: "/etc/supervisor/conf.d",
			rawConfigs: map[string]string{
				"node_exporter_supervisor.conf": `
[inet_http_server]
port = 127.0.0.1:9001
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:              "terraform",
			version:           "0.11.11",
			upstreamURLFormat: "https://releases.hashicorp.com/terraform/%s/terraform_%s_linux_%s.zip",
		}, []string{"arm", "amd64"},
	},

	{
		Options{
			name:      "wifi-local",
			configDir: "/etc/wpa_supplicant",
			rawConfigs: map[string]string{
				"wpa_supplicant.conf": `
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
network={
  ssid="{{.WifiSsid}}"
  psk={{.WifiPsk}}
}
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name:                 "process-exporter",
			user:                 "process-exporter",
			version:              "0.4.0",
			upstreamURLFormat:    "https://github.com/ncabatoff/process-exporter/releases/download/v%s/process-exporter-%s.linux-%s.tar.gz",
			isDaemon:             true,
			argConf:              "-config.path",
			exporterRegisterPort: 9256,
			configFile:           "process-exporter.yml",
		}, []string{"armv6", "amd64"},
	},

	{
		Options{
			name:      "process-exporter-config",
			configDir: "/opt/process-exporter/config",
			rawConfigs: map[string]string{
				"process-exporter.yml": `
process_names:
  - name: "{{.Comm}}"
    cmdline:
    - '.+'
`,
			},
		}, []string{"all"},
	},

	{
		Options{
			name: "script-exporter",
			// We need root to run raspberrypi_exporter.  If we get other scripts
			// that need less privs maybe we'll put them under a different parent.
			user:                 "root",
			version:              "0.1.3",
			upstreamURLFormat:    "https://github.com/ncabatoff/script-exporter/releases/download/v%s/script-exporter_%s_linux_%s.tar.gz",
			isDaemon:             true,
			exporterRegisterPort: 9661,
			argConf:              "-script.path",
		}, []string{"armv6", "amd64"},
	},

	{
		Options{
			name:           "raspberrypi_exporter",
			upstreamScript: "https://raw.githubusercontent.com/ncabatoff/raspberrypi_exporter/master/raspberrypi_exporter",
			binDir:         "/opt/script-exporter/config",
		}, []string{"all"},
	},
}

func buildOrDie(o Options, arches []string, cfg map[string]interface{}) {
	for _, arch := range arches {
		o.arch = arch
		b, err := newBuilder(o)
		if err != nil {
			log.Fatal(err)
		}

		b.build(cfg)
	}
}

type (
	Options struct {
		// name of package
		name string
		// package description
		description string
		// package upstream version
		version string
		// arch, e.g. arm
		arch string
		// template with placeholders for version (twice) and arch
		upstreamURLFormat string
		// path to file to write to binpath
		upstreamScript string
		// if true, create user named after package, and write start/stop scripts
		isDaemon bool
		// for daemons, user to create
		user string
		// if true, invoke wrapper in place of the binary
		wrapper string
		// args to pass on command line immediately after the binary
		args string
		// arg name to give followed by "=$configDir" on command line
		argConf string
		// arg name to give followed by "=$dataDir" on command line
		argData string
		// base name of file within configDir to be given with argConf on command line
		configFile string
		// map from basename to contents that should be written to configDir
		rawConfigs map[string]string
		// packages depended on
		depends []string
		// directory rawConfigs get placed in
		configDir string
		// optional overwrite for default binpath of /opt/$pkgname/bin
		binDir string
		// port to register in consul
		exporterRegisterPort int
	}

	builder struct {
		options Options
		tmpdir  string
	}

	recipe struct {
		Options
		Arches []string
	}
)

func (o Options) basedir() string {
	return fmt.Sprintf("/opt/%s", o.name)
}

func (o Options) configdir() string {
	if o.configDir != "" {
		return o.configDir
	}
	return fmt.Sprintf("%s/config", o.basedir())
}

func (o Options) datadir() string {
	return fmt.Sprintf("%s/data", o.basedir())
}

func (o Options) logdir() string {
	return fmt.Sprintf("%s/log", o.basedir())
}

func (o Options) binpath() string {
	if o.binDir != "" {
		return fmt.Sprintf("%s/%s", o.binDir, o.name)
	} else {
		return fmt.Sprintf("%s/bin/%s", o.basedir(), o.name)
	}
}

func (o Options) command() string {
	var confopt, dataopt string

	if o.argData != "" {
		dataopt = fmt.Sprintf("%s=%s", o.argData, o.datadir())
	}

	if o.argConf != "" {
		confopt = fmt.Sprintf("%s=%s", o.argConf, o.configdir())
		if o.configFile != "" {
			confopt += "/" + o.configFile
		}
	}

	command := fmt.Sprintf("%s %s %s %s", o.binpath(), o.args, confopt, dataopt)
	if o.wrapper != "" {
		return o.binpath() + "-wrapper " + command
	}
	return command
}

func (o Options) getSupervisordConf() string {
	s := fmt.Sprintf(`
[program:%s]
command=%s
stdout_logfile=%s/%s-stdout.log
stderr_logfile=%s/%s-error.log
numprocs=1
autostart=true
autorestart=true
stopsignal=INT
`, o.name, o.command(), o.logdir(), o.name, o.logdir(), o.name)

	if o.user != "" {
		s += fmt.Sprintf("user=%s", o.user)
	}

	return s
}

func (o Options) getScriptPreRemove() string {
	var script string

	if o.isDaemon {
		script += fmt.Sprintf("supervisorctl stop %s\n", o.name)
	}
	if o.exporterRegisterPort != 0 {
		script += fmt.Sprintf("rm -f /opt/consul/config/%s.json\n", o.name)
	}
	if script != "" {
		return "#!/bin/sh\n\n" + script
	}
	return ""
}

func (o Options) getScriptPostRemove() string {
	var script string

	if o.isDaemon {
		script += fmt.Sprintf("rm -f %s/%s.conf\n", supervisorConfDir, o.name)
		if o.user != "" {
			script += fmt.Sprintf("id -u %s 2>/dev/null && userdel %s\n", o.user, o.user)
		}
	}

	if script != "" {
		return "#!/bin/sh\n\n" + script
	}
	return ""
}

func (o Options) getScriptPreInstall() string {
	var script string

	if o.isDaemon {
		if o.user == "" {
			return ""
		}

		script += fmt.Sprintf("id -u %s 2>/dev/null && exit 0\n", o.user)

		if o.user == "nomad" {
			script += fmt.Sprintf(`
		if grep -q '^docker:' /etc/group; then
			useradd -G docker %s 
		else
			useradd %s
		fi
	`, o.user, o.user)
		} else {
			script += fmt.Sprintf("useradd %s\n", o.user)
		}
	}

	if o.exporterRegisterPort != 0 {
		script += fmt.Sprintf(`cat - > /opt/consul/config/%s.json <<EOF
{
	"service": {
	  "id": "%s-$(cat /etc/machine-id)",
	  "name": "%s",
      "tags": ["prom"],
	  "port": %d,
	  "checks": [
		{
		  "id": "%s",
		  "name": "HTTP API on port %d",
		  "http": "http://localhost:%d/metrics",
		  "method": "GET",
		  "interval": "10s",
		  "timeout": "1s"
		}
	  ]
	}
}
EOF
`, o.name, o.name, o.name, o.exporterRegisterPort, o.name, o.exporterRegisterPort, o.exporterRegisterPort)
	}

	if script != "" {
		return "#!/bin/sh\n\n" + script
	}
	return ""
}

func (o Options) getScriptPostInstall() string {
	var script string

	if o.isDaemon {
		if o.user != "" {
			script += fmt.Sprintf("chown -R %s.%s %s\n", o.user, o.user, o.basedir())
		}
		script += fmt.Sprintf("supervisorctl start %s\n", o.name)
	}

	if script != "" {
		return "#!/bin/sh\n\n" + script
	}
	return ""
}

func (o Options) emptyFolders() []string {
	ret := []string{o.configdir()}
	if o.argData != "" {
		ret = append(ret, o.datadir())
	}
	if o.isDaemon {
		ret = append(ret, o.logdir())
	}

	return ret
}

func newBuilder(o Options) (*builder, error) {
	dir, err := ioutil.TempDir("", o.name)
	if err != nil {
		return nil, err
	}
	return &builder{options: o, tmpdir: dir}, nil
}

func (b *builder) writeNonEmptyFileOrDie(name, body string) string {
	if body == "" {
		return ""
	} else {
		return b.writeFileOrDie(name, body)
	}
}

func (b *builder) writeFileOrDie(name, body string) string {
	tmppath := filepath.Join(b.tmpdir, name)
	f, err := os.Create(tmppath)
	if err != nil {
		log.Fatalf("error creating tempfile %q: %v", name, err)
	}
	_, err = io.Copy(f, strings.NewReader(body))
	if err != nil {
		log.Fatalf("error writing tempfile %q: %v", name, err)
	}
	err = f.Close()
	if err != nil {
		log.Fatalf("error writing tempfile %q: %v", name, err)
	}
	return tmppath
}

func (b *builder) writeScripts() nfpm.Scripts {
	return nfpm.Scripts{
		PreInstall:  b.writeNonEmptyFileOrDie("preinst", b.options.getScriptPreInstall()),
		PostInstall: b.writeNonEmptyFileOrDie("postinst", b.options.getScriptPostInstall()),
		PreRemove:   b.writeNonEmptyFileOrDie("prerm", b.options.getScriptPreRemove()),
		PostRemove:  b.writeNonEmptyFileOrDie("postrm", b.options.getScriptPostRemove()),
	}
}

func (o Options) getURL() string {
	if o.upstreamScript != "" {
		if o.upstreamURLFormat != "" {
			log.Fatalf("Bad package spec %q:specify both upstreamURLFormat and upstreamScript", o.name)
		}
		return o.upstreamScript
	}
	if o.upstreamURLFormat != "" {
		return fmt.Sprintf(o.upstreamURLFormat, o.version, o.version, o.arch)
	}
	return ""
}

func (b *builder) getBinary() string {
	o := b.options
	name := fmt.Sprintf("%s-%s-%s", o.name, o.version, o.arch)
	binname := "bin/" + name
	dldir := "downloads/" + name

	_, err := os.Stat(binname)
	if err == nil {
		return binname
	}
	if _, ok := err.(*os.PathError); !ok {
		log.Fatalf("error stating %q: %v", o.name, err)
	}

	url := o.getURL()
	cmd := exec.Command("go-getter", url, dldir)
	err = cmd.Run()
	if err != nil {
		log.Fatalf("error fetching %s: %v", url, err)
	}

	var source os.FileInfo

	{
		fis, err := ioutil.ReadDir(dldir)
		if err != nil {
			log.Fatalf("error reading dir %s: %v", dldir, err)
		}

		// We support either a single file with arbitrary name, or a single directory
		// containing 1+ files of which one is named after the project.
		if len(fis) == 1 {
			source = fis[0]
		} else {
			var fnames []string
			for _, fi := range fis {
				fnames = append(fnames, fi.Name())
				if fi.Name() == o.name {
					source = fi
				}
			}
			if source == nil {
				log.Fatalf("expected exactly one file in %s, but found: %v", dldir, fnames)
			}
		}
	}

	src := filepath.Join(dldir, source.Name())
	if source.IsDir() {
		src = filepath.Join(dldir, source.Name(), o.name)
	}

	_ = os.Mkdir("bin", 0755)
	err = os.Link(src, binname)
	if err != nil {
		log.Fatalf("error hard linking %s to %s: %v", src, binname, err)
	}

	if source.Mode().Perm()&0111 != 0111 {
		err = os.Chmod(binname, source.Mode().Perm()|0111)
		if err != nil {
			log.Fatalf("error chmodding %s to %o: %v", binname, source.Mode().Perm()|0111, err)
		}
	}

	return binname
}

func (b *builder) writeFiles(cfg map[string]interface{}) map[string]string {
	ret := make(map[string]string)

	if b.options.getURL() != "" {
		ret[b.getBinary()] = b.options.binpath()
	}

	if b.options.wrapper != "" {
		dest := b.writeFileOrDie(b.options.name+"-wrapper", b.options.wrapper)
		if err := os.Chmod(dest, 0755); err != nil {
			log.Fatalf("error chmod %s: %v", dest, err)
		}

		ret[dest] = b.options.binpath() + "-wrapper"
	}

	for name, contents := range b.options.rawConfigs {
		tmpl := template.New(name)
		tmpl = tmpl.Funcs(template.FuncMap{"jsm": func(arg interface{}) (string, error) {
			b, err := json.Marshal(arg)
			return string(b), err
		}})
		tmpl, err := tmpl.Parse(contents)
		if err != nil {
			log.Fatalf("error building package %s, file %s: %v", b.options.name, name, err)
		}
		var buf bytes.Buffer
		err = tmpl.Execute(&buf, cfg)
		if err != nil {
			log.Fatalf("error building package %s, file %s: %v", b.options.name, name, err)
		}

		dest := b.writeFileOrDie(name, buf.String())
		ret[dest] = filepath.Join(b.options.configdir(), name)
	}

	return ret
}

func (b *builder) writeSupervisorConf() map[string]string {
	tmp := b.writeFileOrDie("superconf-"+b.options.name, b.options.getSupervisordConf())
	dest := fmt.Sprintf("%s/%s.conf", supervisorConfDir, b.options.name)
	return map[string]string{tmp: dest}
}

func (b *builder) build(cfg map[string]interface{}) {
	depends := append([]string{}, b.options.depends...)
	var cfgFiles map[string]string
	if b.options.isDaemon {
		//depends = append(depends, "supervisor")
		cfgFiles = b.writeSupervisorConf()
	}

	arch := b.options.arch
	switch b.options.arch {
	case "armv7":
		arch = "armhf"
	case "armv6":
		arch = "armel"
	}

	version := b.options.version
	if version == "" {
		version = "0.0.1"
	}

	info := nfpm.WithDefaults(nfpm.Info{
		Name:        b.options.name,
		Maintainer:  "me@example.com",
		Homepage:    "https://github.com/ncabatoff/piinit",
		Arch:        arch,
		Version:     version,
		Description: b.options.description,
		Bindir:      b.options.basedir() + "/bin",
		Overridables: nfpm.Overridables{
			Depends:      depends,
			Files:        b.writeFiles(cfg),
			ConfigFiles:  cfgFiles,
			EmptyFolders: b.options.emptyFolders(),
			Scripts:      b.writeScripts(),
		},
	})

	_ = os.Mkdir(b.options.arch, 0755)

	pkgfile := filepath.Join(b.options.arch, b.options.name+".deb")
	out, err := os.Create(pkgfile)
	if err != nil {
		log.Fatalf("error writing deb: %v", pkgfile)
	}

	pkgr, err := nfpm.Get("deb")
	if err != nil {
		log.Fatalf("no deb packager: %v", err)
	}

	err = pkgr.Package(info, out)
	if err != nil {
		log.Fatalf("error writing deb: %v", err)
	}
}

func main() {
	var (
		flagArches   = flag.String("arches", "all,amd64,arm,armv6", "arches to build")
		flagPackages = flag.String("packages", "", "packages to build, or all if none specified")
		flagConfig   = flag.String("config", "", "json package config")
	)
	flag.Parse()
	var desiredArch = make(map[string]struct{})
	for _, arch := range strings.Split(*flagArches, ",") {
		desiredArch[arch] = struct{}{}
	}

	var cfg = make(map[string]interface{})
	if *flagConfig != "" {
		err := json.Unmarshal([]byte(*flagConfig), &cfg)
		if err != nil {
			log.Fatalf("error parsing json config argument %q: %v", *flagConfig, err)
		}
		log.Printf("config: %v", cfg)
	}

	var desiredPackage = make(map[string]struct{})
	if *flagPackages != "" {
		for _, pkg := range strings.Split(*flagPackages, ",") {
			desiredPackage[pkg] = struct{}{}
		}
	} else {
		for _, recipe := range recipes {
			desiredPackage[recipe.name] = struct{}{}
		}
	}

	for _, recipe := range recipes {
		if _, ok := desiredPackage[recipe.name]; !ok {
			continue
		}

		var arches []string
		for _, arch := range recipe.Arches {
			if _, ok := desiredArch[arch]; ok {
				arches = append(arches, arch)
			}
		}
		if len(arches) > 0 {
			buildOrDie(recipe.Options, arches, cfg)
		}
	}
}
