Example implementation of SDS server
====================================

[This file](./sds.go) contains the code of SDS server that can be used for experimenting with
SDS and Envoy. By no means it can be used in production since it can serve
only one Envoy instance and it's here for illustrative purposes only.

Copy the file to a directory inside your Go workspace, e.g. `$HOME/go/src/sds/sds.go`.

Then change to the directory `$HOME/go/src/sds` and type
```
$ dep init
$ go build
```

If everything is OK then a new executable `$HOME/go/src/sds/sds` gets created.

Then go to the hardcoded folder where the experimental SDS server looks for keys
and generate the first key pair.

```
$ mkdir /tmp/keys
$ openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout key.pem -out cert.pem
```

Run the SDS server

```
$ $HOME/go/src/sds/sds &
```

Finally you can launch Envoy. For that the following Envoy config needs to be
placed to a file, e.g. $HOME/go/src/sds/envoy.yaml (Do not forget to update it with
your domain names you used as CN when created the SSL keys).

```yaml
node:
  id: node1
  cluster: cluster1
admin:
  access_log_path: /tmp/admin_access.log
  address:
    socket_address:
      protocol: TCP
      address: 127.0.0.1
      port_value: 9901
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: 10000
    listener_filters:
    - name: "envoy.listener.tls_inspector"
      config: {}
    filter_chains:
    - filter_chain_match:
        server_names: ["mydesk.example.com"]
      tls_context:
        require_client_certificate: false
        common_tls_context:
          tls_certificate_sds_secret_configs:
          - name: server_cert
            sds_config:
              api_config_source:
                api_type: GRPC
                grpc_services:
                  envoy_grpc:
                    cluster_name: sds_server_uds
      filters:
      - name: envoy.http_connection_manager
        config:
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  host_rewrite: mydesk.example.com
                  cluster: service_webtest_desk
          http_filters:
          - name: envoy.router
  clusters:
  - name: service_webtest_desk
    connect_timeout: 0.25s
    type: LOGICAL_DNS
    # Comment out the following line to test on v6 networks
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    hosts:
      - socket_address:
          address: mydesk.example.com
          port_value: 8008
  - name: sds_server_uds
    connect_timeout: 1s
    http2_protocol_options: {}
    hosts:
      - pipe:
          path: /tmp/sds.sock

```

Launch Envoy:

```
$ path/to/envoy  --v2-config-only -l info -c $HOME/go/src/sds/envoy.yaml
```
