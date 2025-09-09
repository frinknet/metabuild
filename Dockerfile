# (c) 2025 FRINKnet & Friends - 0BSD licence
FROM alpine:latest AS build

# Install dependencies for OSXCross
RUN apk add --no-cache \
	bash \
	build-base \
	make \
	git \
	curl \
	cmake \
	llvm \
	clang \
	libxml2-dev \
	openssl-dev \
	musl-fts-dev \
	bsd-compat-headers \
	python3

# Build XCC with prefix awareness, then rename during copy
RUN git clone --depth 1 https://github.com/tyfkda/xcc.git /opt/xcc \
 && make -C /opt/xcc CC=clang \
 && mkdir -p /usr/local/xcc/bin/ \
 && cp /opt/xcc/xcc /usr/local/xcc/bin/ \
 && cp /opt/xcc/cc1 /usr/local/xcc/bin/ \
 && cp /opt/xcc/cpp /usr/local/xcc/bin/ \
 && cp /opt/xcc/as /usr/local/xcc/bin/ \
 && cp /opt/xcc/ld /usr/local/xcc/bin/

# Download latest SDK, clone OSXCross, and build in the right order
RUN LATEST_SDK=$(curl -s https://api.github.com/repos/joseluisq/macosx-sdks/releases/latest | \
	grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$') && \
	echo "Auto-downloading macOS SDK: $LATEST_SDK" && \
	curl -fsSL "https://github.com/joseluisq/macosx-sdks/releases/download/$LATEST_SDK/MacOSX$LATEST_SDK.sdk.tar.xz" \
	-o /tmp/MacOSX$LATEST_SDK.sdk.tar.xz && \
	git clone --depth 1 https://github.com/tpoechtrager/osxcross.git /opt/osxcross && \
	mv /tmp/MacOSX$LATEST_SDK.sdk.tar.xz /opt/osxcross/tarballs/ && \
	UNATTENDED=1 /opt/osxcross/build.sh

# Now for the real container
FROM alpine:latest
# Install cross-compilation support
RUN apk add --no-cache \
	tcc \
	make \
	cmake \
	git \
	llvm \
	lld \
	clang \
	libxml2 \
	openssl \
	wasm-tools \
	mingw-w64-gcc \
	bash-completion

# Copy compiled tools
COPY --from=build /usr/local/xcc/		 /usr/local/xcc/
COPY --from=build /opt/osxcross/target/		/opt/osxcross/

# Copy metabuild source
COPY . /metabuild

# Set up bash environment
RUN echo 'export PS1="\n\[\e[1;91m\]	\w \[\e[38;5;52m\]\$\[\e[0m\] "' >> /etc/bash/bashrc && \
	echo 'export PATH="/opt/osxcross/bin:/usr/local/xcc/bin:/usr/local/bin:$PATH"' >> /etc/bash/bashrc && \
	wasm-tools completion bash >> /etc/bash/bashrc

# Create bootstrap entrypoint script
RUN cat > /bin/metabuild <<'EOF' && chmod +x /bin/metabuild
#!/bin/bash
set -e
cd /build

cpmaybe() {
	local src="$1"
	local dir="$2"
	local file="${src##*/}"
	local dest="$dir/$file"

	if [[ -f "$dest" ]]; then
		read -p "$dest exists. Overwrite? (y/N): " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			cp "$src" "$dir"
			echo "✓ $dest"
		else
			echo "✗ $dest"
		fi
	else
		cp "$src" "$dir"
		echo "✓ $dest"
	fi
}

case "${1:-}" in
	cli)
		shift
		exec bash "$@"
		;;
	init)
		echo "Installing metabuild files..."

		for file in build.sh build.bat; do
			cpmaybe "/metabuild/$file" .
		done

		mkdir -p .metabuild

		for file in /metabuild/*.mk; do
			cpmaybe "$file" .metabuild
		done

		echo "Run 'metabuild' to build your project."
		;;
	extend)
		cpmaybe /metabuild/Makefile .
		;;
	*)
		mkdir -p .metabuild
		cp -n /metabuild/*.mk .metabuild/

		if [[ -f Makefile ]]; then
			exec make "$@"
		else
			exec make -f /metabuild/Makefile "$@"
		fi
		;;
esac
EOF

ENV BASH_ENV="/etc/bash/bashrc"
WORKDIR /build
ENTRYPOINT ["/bin/metabuild"]
