# Auto setup a PKI infrastructure to
# enable HTTPS on nginx


if test -f /etc/ssl/kiloupresquetout.local.crt; then
    echo ""
    echo "[*] Certs already created"
    echo ""
else
    # 1.1 Create directories
    mkdir -p ca/root-ca/private ca/root-ca/db crl certs
    chmod 700 ca/root-ca/private

    # 1.2 Create database
    cp /dev/null ca/root-ca/db/root-ca.db
    cp /dev/null ca/root-ca/db/root-ca.db.attr
    echo 01 > ca/root-ca/db/root-ca.crt.srl
    echo 01 > ca/root-ca/db/root-ca.crl.srl

    # 1.3 Create CA request
    openssl req -new \
        -config etc/root-ca.conf \
        -out ca/root-ca.csr \
        -keyout ca/root-ca/private/root-ca.key

    # 1.4 Create CA certificate
    openssl ca -selfsign \
        -config etc/root-ca.conf \
        -in ca/root-ca.csr \
        -out ca/root-ca.crt \
        -extensions root_ca_ext

    # 2.1 Create directories
    mkdir -p ca/signing-ca/private ca/signing-ca/db crl certs
    chmod 700 ca/signing-ca/private

    # 2.2 Create database
    cp /dev/null ca/signing-ca/db/signing-ca.db
    cp /dev/null ca/signing-ca/db/signing-ca.db.attr
    echo 01 > ca/signing-ca/db/signing-ca.crt.srl
    echo 01 > ca/signing-ca/db/signing-ca.crl.srl

    # 2.3 Create CA request
    openssl req -new \
        -config etc/signing-ca.conf \
        -out ca/signing-ca.csr \
        -keyout ca/signing-ca/private/signing-ca.key

    #2.4 Create CA certificate
    openssl ca \
        -config etc/root-ca.conf \
        -in ca/signing-ca.csr \
        -out ca/signing-ca.crt \
        -extensions signing_ca_ext

    # 3.3 Create TLS server request
    SAN=DNS:www.kiloupresquetout.local \
    openssl req -new \
        -config etc/server.conf \
        -out certs/kiloupresquetout.local.csr \
        -keyout certs/kiloupresquetout.local.key

    # 3.4 Create TLS server certificate
    openssl ca \
        -config etc/signing-ca.conf \
        -in certs/kiloupresquetout.local.csr \
        -out certs/kiloupresquetout.local.crt \
        -extensions server_ext

    # Export cert
    cp ca/root-ca.crt ./root-ca.crt
    mkdir /etc/ssl 2> /dev/null
    cp certs/kiloupresquetout.local.crt /etc/ssl/kiloupresquetout.local.crt
    cp certs/kiloupresquetout.local.key /etc/ssl/kiloupresquetout.local.key 
    cat ca/signing-ca.crt ca/root-ca.crt > /etc/ssl/chain.crt
fi

echo ""
echo "=====CONFIG APACHE2====="
echo ""


# Setup apache2
echo '
LoadModule ssl_module modules/mod_ssl.so

Listen 443
<VirtualHost *:443>
    ServerName www.example.com
    SSLEngine on
    SSLCertificateFile "/etc/ssl/kiloupresquetout.local.crt"
    SSLCertificateKeyFile "/etc/ssl/kiloupresquetout.local.key"
    SSLCertificateChainFile "/etc/ssl/chain.crt"
</VirtualHost>
' > /etc/apache2/sites-available/kilou.conf


a2enmod ssl
a2ensite kilou
service apache2 reload

a2dissite 000-default