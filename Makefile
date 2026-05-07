.PHONY: install
install:
	zig build --prefix zig-release --release=safe
	sudo install -m 755 ./zig-release/bin/battray /opt/bin/battray
