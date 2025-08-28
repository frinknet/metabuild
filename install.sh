#!/bin/sh
REPO="ghcr.io/frinknet/metabuild"
IMAGE="${REPO##*/}"
PREFIX="${HOME}/bin"

# Is prefix in path
mkdir -p "$PREFIX"
case ":$PATH:" in
	"$PREFIX":*) ;;
	*:"$PREFIX":*) ;;
	*:"$PREFIX") ;;
	*) echo "export PATH=\"$PREFIX:\$PATH\"" >> "$HOME/.bashrc"; . "$HOME/.bashrc";;
esac

# Pull the container
if ! docker pull "$REPO:latest"; then
	echo "could not pull docker container $REPO:latest"
fi

# Create a shell wrapper
cat > "$PREFIX/$IMAGE" <<EOF
#!/bin/sh
exec docker run --rm -it -v "\$(pwd):/work" $REPO "\$@"
EOF

# Make executable
chmod +x "$PREFIX/$IMAGE"

# Report what you did
echo
echo "✓ metabuild installed: $PREFIX/$IMAGE"
echo
echo "Run 'metabuild init' to get started."
echo
