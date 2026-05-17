.PHONY: install
install:
	zig build --prefix zig-release --release=safe
	sudo install -m 755 ./zig-release/bin/battray /opt/bin/battray

.PHONY: install-debug
install-debug:
	zig build
	sudo install -m 755 ./zig-out/bin/battray /opt/bin/battray

.PHONY: update-deps
update-deps:
	zig fetch --save git+https://github.com/baverman/zix11.git
