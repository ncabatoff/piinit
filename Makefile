%.json: %.jsonnet provisioners.jsonnet
	jsonnet -o $@ $<

all: packer-arm.json packer-docker.json packer-docker-server-cn.json packer-docker-server-mon.json