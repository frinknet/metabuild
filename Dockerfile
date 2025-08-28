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
	libxml2 \
	openssl \
	python3

# Build XCC using GCC as bootstrap compiler
RUN git clone --depth 1 https://github.com/tyfkda/xcc.git /opt/xcc \
 && make -C /opt/xcc CC=clang \
 && cp /opt/xcc/xcc /usr/local/bin/ 

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
	build-base \
	make \
	git \
	llvm \
	lld \
	clang \
	mingw-w64-gcc \
	libxml2-dev \
	openssl-dev \
	python3 \
	wasm-tools \
	bash-completion

# Copy compiled tools
COPY --from=build /opt/xcc/out/		   /usr/local/
COPY --from=build /opt/osxcross/target/    /opt/osxcross/

# Copy metabuild source
COPY . /metabuild

# Set up bash environment
RUN echo 'export PS1="\n\[\e[1;91m\]  \w \[\e[38;5;52m\]\$\[\e[0m\] "' >> /root/.bashrc && \
	echo 'export PATH="/opt/osxcross/bin:/usr/local/bin:$PATH"' >> /root/.bashrc && \
	wasm-tools completion bash >> /root/.bashrc

# Create bootstrap entrypoint script
RUN cat > /bin/metabuild <<'EOF' && chmod +x /bin/metabuild
#!/bin/bash
set -e

# Bootstrap project files if they don't exist
if [[ ! -f /work/Makefile && -f /metabuild/Makefile ]]; then
	echo "Bootstrapping Makefile from /metabuild"
	cp /metabuild/Makefile /work/
fi

if [[ ! -f /work/build.sh && -f /metabuild/build.sh ]]; then
	echo "Bootstrapping build.sh from /metabuild"
	cp /metabuild/build.sh /work/
fi

if [[ ! -f /work/build.bat && -f /metabuild/build.bat ]]; then
	echo "Bootstrapping build.bat from /metabuild"
	cp /metabuild/build.bat /work/
fi

if [[ ! -d /work/.metabuild && -d /metabuild/.metabuild ]]; then
	echo "Bootstrapping .metabuild directory from /metabuild"
	cp -r /metabuild/.metabuild /work/
fi

# Run make with all arguments
cd /work
exec make "$@"
EOF

WORKDIR /work
ENTRYPOINT ["/bin/metabuild"]
