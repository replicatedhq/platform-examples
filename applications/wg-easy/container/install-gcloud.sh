case $(uname -m) in 
  aarch64|arm64)
    export ARCH="arm";;
  x86_64)
    export ARCH="x86_64";;
  *)
    echo "unsupported arch"; exit 1;;
esac  

curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-$ARCH.tar.gz | tar xz

./google-cloud-sdk/install.sh -q

find /google-cloud-sdk/bin -mindepth 1 -maxdepth 1 -type f -exec ln -s {} /usr/bin \;
