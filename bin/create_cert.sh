exit 0
openssl req \
    -newkey rsa:4096 -nodes -sha256 -keyout registry.key \
    -x509 -days 365 -out registry.crt \
    -addext 'subjectAltName = IP:18.197.84.53' \
    -subj '/C=ES/ST=Gipuzkoa/L=Orereta/O=Foo/OU=Bar/CN=myregistrydomain.com/'

