<img src="assets/NSS-128x128.png" align="right" />

# shibboleth-sp

Docker container building latest [Shibboleth Service Provider 3](https://shibboleth.atlassian.net/wiki/spaces/SP3/overview) from sources with [Nginx](https://nginx.org/en/).

## Disclaimer

This image is purposely designed to offer a **non-encrypted** (http) endpoint assuming an SSL-offloading reverse proxy like [Traefik](https://doc.traefik.io/traefik/) sits in-front of it. This takes the burden of configuring SSL off of this image while the Shibboleth backend will remain under the impression (due to use of FastCGI parameters) that SSL is used all the way.

## Usage

- Clone and build the repository.
- Copy the provided `nginx-default.example.conf` to `nginx-default.conf` and set the `SERVER_NAME` correctly.
- Copy the provided `docker-compose.example.yml` to `docker-compose.yml` and adapt accordingly.
- Create a `data/` sub-directory and place the following files there:
  - attribute-map.xml
  - shibboleth2.xml
  - sp-cert.pem
  - sp-key.pem

## Sources

- [Shibboleth auth request module for Nginx](https://github.com/nginx-shib/nginx-http-shibboleth)
