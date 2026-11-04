# Politique umask Helios selon le groupe principal
if id -nG "$USER" | grep -qw transport; then
    umask 002
else
    umask 027
fi
