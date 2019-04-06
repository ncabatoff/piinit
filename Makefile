%.json: %.jsonnet
	jsonnet $< -o $@

./pkgbuilder: cmd/pkgbuilder/main.go
	cd cmd/pkgbuilder && GO111MODULE=on go build -o ../../pkgbuilder

packages: pkgbuilder
	@mkdir -p packages
	cd packages && ../pkgbuilder && touch .

