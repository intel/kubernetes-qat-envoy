Example implementation of SDS server
====================================

Below is the code of SDS server that can be used for experimenting with
SDS and Envoy. By no means it can be used in production since it can serve
only one Envoy instance and it's here for illustrative purposes only.

```go
// Copyright 2018 Intel Corporation. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"os"
	"time"

	xdsapi "github.com/envoyproxy/go-control-plane/envoy/api/v2"
	authapi "github.com/envoyproxy/go-control-plane/envoy/api/v2/auth"
	"github.com/envoyproxy/go-control-plane/envoy/api/v2/core"
	sdsapi "github.com/envoyproxy/go-control-plane/envoy/service/discovery/v2"
	"github.com/fsnotify/fsnotify"
	"github.com/gogo/protobuf/types"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const (
	// XXX: Since this sample code was written solely for illustrative purposes
	//      only one client is allowed to connect to this server.
	//      Also in order to harden security even more only one gRPC call
	//      is allowed to be made through this connection.
	maxConnections = 1

	maxStreams = 100000
)

// Options provides all of the configuration parameters for secret discovery service.
type Options struct {
	// UDSPath is the unix domain socket through which SDS server communicates with proxies.
	UDSPath string
}

type secretItem struct {
	certificateChain []byte
	privateKey       []byte
}

type sds struct {
	// TODO: we should track more than one nonce. One nonce limits us to have only one Envoy process per SDS server.
	lastNonce string

	connectionNum int
}

func (s *sds) sdsDiscoveryResponse(si *secretItem, proxyID string) (*xdsapi.DiscoveryResponse, error) {
	s.lastNonce = time.Now().String()
	resp := &xdsapi.DiscoveryResponse{
		TypeUrl:     "type.googleapis.com/envoy.api.v2.auth.Secret",
		VersionInfo: s.lastNonce,
		Nonce:       s.lastNonce,
	}

	if si == nil {
		fmt.Printf("SDS: got nil secret for proxy %q", proxyID)
		return resp, nil
	}

	secret := &authapi.Secret{
		// TODO: get rid of hardcoded names
		Name: "server_cert",
	}
	secret.Type = &authapi.Secret_TlsCertificate{
		TlsCertificate: &authapi.TlsCertificate{
			CertificateChain: &core.DataSource{
				Specifier: &core.DataSource_InlineBytes{
					InlineBytes: si.certificateChain,
				},
			},
			PrivateKey: &core.DataSource{
				Specifier: &core.DataSource_InlineBytes{
					InlineBytes: si.privateKey,
				},
			},
		},
	}

	ms, err := types.MarshalAny(secret)
	if err != nil {
		fmt.Printf("Failed to mashal secret for proxy %q: %v", proxyID, err)
		return nil, err
	}
	resp.Resources = append(resp.Resources, *ms)

	return resp, nil
}

func getSecretItem() (*secretItem, error) {
	cert, err := ioutil.ReadFile("/tmp/keys/cert.pem")
	if err != nil {
		fmt.Println("Failed to read cert chain", err)
		return nil, err
	}
	key, err := ioutil.ReadFile("/tmp/keys/key.pem")
	if err != nil {
		fmt.Println("Failed to read private key", err)
		return nil, err
	}

	secret := &secretItem{
		certificateChain: cert,
		privateKey:       key,
	}

	return secret, nil
}

func (s *sds) isConnectionAllowed() error {
	if s.connectionNum >= maxConnections {
		return errors.New("this sample code is allowed to serve only one client, only once and no matter which gRPC call")
	}

	s.connectionNum++

	return nil
}

func (s *sds) FetchSecrets(ctx context.Context, discReq *xdsapi.DiscoveryRequest) (*xdsapi.DiscoveryResponse, error) {
	if err := s.isConnectionAllowed(); err != nil {
		return nil, err
	}

	secret, err := getSecretItem()
	if err != nil {
		return nil, err
	}

	return s.sdsDiscoveryResponse(secret, discReq.Node.Id)
}

func (s *sds) StreamSecrets(stream sdsapi.SecretDiscoveryService_StreamSecretsServer) error {
	var recvErr error
	var nodeID string

	if err := s.isConnectionAllowed(); err != nil {
		return err
	}

	reqChannel := make(chan *xdsapi.DiscoveryRequest, 1)

	go func() {
		defer close(reqChannel)
		for {
			var req *xdsapi.DiscoveryRequest

			req, recvErr = stream.Recv()
			if recvErr != nil {
				if status.Code(recvErr) == codes.Canceled || recvErr == io.EOF {
					fmt.Printf("SDS: connection terminated %+v\n", recvErr)
					return
				}
				fmt.Printf("SDS: connection terminated with errors %+v\n", recvErr)
				return
			}
			reqChannel <- req
		}
	}()

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		fmt.Println("Failed to create watcher:", err)
		return err
	}
	defer watcher.Close()

	err = watcher.Add("/tmp/keys/cert.pem")
	if err != nil {
		fmt.Println("Failed to add /tmp/keys/cert.pem to watcher:", err)
		return err
	}

	for {
		select {
		case discReq, ok := <-reqChannel:
			if !ok {
				return recvErr
			}
			if discReq.ErrorDetail != nil {
				return errors.New("Envoy error")
			}
			if len(s.lastNonce) > 0 && discReq.ResponseNonce == s.lastNonce {
				continue
			}
			if discReq.Node == nil {
				fmt.Println("Invalid discovery request with no node")
				return errors.New("Invalid discovery request with no node")
			}

			nodeID = discReq.Node.Id

			secret, err := getSecretItem()
			if err != nil {
				return err
			}
			response, err := s.sdsDiscoveryResponse(secret, nodeID)
			if err != nil {
				fmt.Println(err)
				return err
			}
			if err := stream.Send(response); err != nil {
				fmt.Println("Failed to send:", err)
				return err
			}
		case ev := <-watcher.Events:
			if ev.Op == fsnotify.Remove || ev.Op == fsnotify.Rename {
				fmt.Println("Key file was deleted")
				return errors.New("Key file was deleted")
			}
			secret, err := getSecretItem()
			if err != nil {
				return err
			}
			response, err := s.sdsDiscoveryResponse(secret, nodeID)
			if err != nil {
				fmt.Println(err)
				return err
			}
			if err := stream.Send(response); err != nil {
				fmt.Println("Failed to send:", err)
				return err
			}
		case err := <-watcher.Errors:
			fmt.Println("Watcher got error:", err)
			return err
		}
	}
}

type server struct {
	grpcServer *grpc.Server
	sds        *sds
}

func grpcServerOptions() []grpc.ServerOption {
	grpcOptions := []grpc.ServerOption{
		grpc.MaxConcurrentStreams(uint32(maxStreams)),
	}

	return grpcOptions
}

func (s *server) setupAndServe(options *Options) error {
	// Remove unix socket before use.
	if err := os.Remove(options.UDSPath); err != nil && !os.IsNotExist(err) {
		return errors.Wrapf(err, "Failed to remove unix://%s", options.UDSPath)
	}

	lis, err := net.Listen("unix", options.UDSPath)
	if err != nil {
		return errors.Wrap(err, "Failed to listen to plugin socket")
	}

	s.grpcServer = grpc.NewServer(grpcServerOptions()...)
	sdsapi.RegisterSecretDiscoveryServiceServer(s.grpcServer, s.sds)
	fmt.Println("Start SDS at:", options.UDSPath)
	return s.grpcServer.Serve(lis)
}

func main() {
	socketEndpoint := flag.String("socket", "/tmp/sds.sock", "unix socket SDS listens to")
	flag.Parse()

	options := &Options{
		UDSPath: *socketEndpoint,
	}
	server := &server{
		sds: &sds{
			connectionNum: 0,
		},
	}
	err := server.setupAndServe(options)
	if err != nil {
		fmt.Printf("ERROR: %+v\n", err)
		os.Exit(1)
	}
}
```

Put the code into a file inside your Go workspace, e.g. `$HOME/go/src/sds/sds.go`.

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
