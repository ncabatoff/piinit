%.json: %.jsonnet provisioners.jsonnet
	jsonnet -o $@ $<

all: packer-arm.json packer-docker.json