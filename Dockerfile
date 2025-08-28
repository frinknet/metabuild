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
RUN git clone --depth 1 https://github.com/tyfkda/xcc.git /opt/xcc && \
	make -C /opt/xcc CC=gcc && make -C /opt/xcc install PREFIX=/opt/xcc/out

# Build OSXCross for macOS cross-compilation
RUN git clone --depth 1 https://github.com/tpoechtrager/osxcross.git /opt/osxcross && \
	UNATTENDED=1 /opt/osxcross/build.sh

#TODO extract https://github.com/joseluisq/macosx-sdks/tags

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

# two fun builds
COPY --from=build /opt/xcc/out/		   /usr/local/
COPY --from=build /opt/osxcross/target/    /opt/osxcross/

# bash behave
RUN wasm-tools completion bash >> /root/.bashrc \
&& cat <<'EOF' > /root/.bashrc
trap echo DEBUG
echo 'export PS1="\n\[\e[1;91m\]  \w \[\e[38;5;52m\]\$\[\e[0m\] \[\e]12;#999900\007\]\[\e]12;#999900\007\]\[\e[3 q\]"' >> /root/.bashrc
PATH="/opt/osxcross/bin:/usr/local/bin:$PATH"
EOF

WORKDIR /work
ENTRYPOINT ["make"]
