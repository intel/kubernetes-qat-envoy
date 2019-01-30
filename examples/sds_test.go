// Copyright 2019 Intel Corporation. All Rights Reserved.
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
	"bytes"
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"testing"
	"time"

	xdsapi "github.com/envoyproxy/go-control-plane/envoy/api/v2"
	"github.com/envoyproxy/go-control-plane/envoy/api/v2/core"
	"github.com/pkg/errors"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

func TestSdsDiscoveryResponse(t *testing.T) {
	server := &sds{}
	si := &secretItem{
		certificateChain: []byte("bla-bla"),
		privateKey:       []byte("bla-bla"),
	}

	resp, err := server.sdsDiscoveryResponse(si, "")
	if err != nil {
		t.Errorf("Unexpected error: %+v", err)
	}
	fmt.Println(resp, err)
}

func TestGetSecretItem(t *testing.T) {
	tmpDir := fmt.Sprintf("/tmp/sds-test-%d/", time.Now().Unix())
	tcases := []struct {
		certFile    []byte
		keyFile     []byte
		expectedErr bool
	}{
		{
			certFile:    []byte("fake cert"),
			keyFile:     []byte("fake key"),
			expectedErr: false,
		},
		{
			certFile:    []byte("fake cert"),
			expectedErr: true,
		},
		{
			keyFile:     []byte("fake key"),
			expectedErr: true,
		},
	}
	for _, tt := range tcases {
		err := os.MkdirAll(tmpDir, 0755)
		if err != nil {
			t.Fatalf("Failed to create fake device directory: %+v", err)
		}
		if tt.certFile != nil {
			if err := ioutil.WriteFile(path.Join(tmpDir, "cert.pem"), tt.certFile, 0644); err != nil {
				t.Fatalf("Failed to create fake vendor file: %+v", err)
			}
		}
		if tt.keyFile != nil {
			if err := ioutil.WriteFile(path.Join(tmpDir, "key.pem"), tt.keyFile, 0644); err != nil {
				t.Fatalf("Failed to create fake vendor file: %+v", err)
			}
		}

		si, err := getSecretItem(tmpDir)

		if tt.expectedErr && err == nil {
			t.Error("Expected error hasn't been triggered")
		}
		if !tt.expectedErr && err != nil {
			t.Errorf("Unexpected error: %+v", err)
		}
		if err == nil && !(bytes.Equal(tt.certFile, si.certificateChain) && bytes.Equal(tt.keyFile, si.privateKey)) {
			t.Error("File content is wrong")
		}
		err = os.RemoveAll(tmpDir)
		if err != nil {
			t.Fatalf("Failed to remove fake device directory: %+v", err)
		}
	}
}

func TestIsConnectionAllowed(t *testing.T) {
	tcases := []struct {
		connectionNum int
		expectedErr   bool
	}{
		{
			expectedErr: false,
		},
		{
			connectionNum: maxConnections,
			expectedErr:   true,
		},
	}
	for _, tt := range tcases {
		s := &sds{
			connectionNum: tt.connectionNum,
		}
		err := s.isConnectionAllowed()
		if tt.expectedErr && err == nil {
			t.Error("Expected error hasn't been triggered")
		}
		if !tt.expectedErr && err != nil {
			t.Errorf("Unexpected error: %+v", err)
		}
	}
}

func TestFetchSecrets(t *testing.T) {
	tmpDir := fmt.Sprintf("/tmp/sds-testfetch-%d/", time.Now().Unix())
	tcases := []struct {
		certFile      []byte
		keyFile       []byte
		connectionNum int
		expectedErr   bool
	}{
		{
			certFile:    []byte("fake cert"),
			keyFile:     []byte("fake key"),
			expectedErr: false,
		},
		{
			certFile:      []byte("fake cert"),
			keyFile:       []byte("fake key"),
			connectionNum: maxConnections,
			expectedErr:   true,
		},
		{
			certFile:    []byte("fake cert"),
			expectedErr: true,
		},
	}
	for _, tt := range tcases {
		if err := os.MkdirAll(tmpDir, 0755); err != nil {
			t.Fatalf("Failed to create fake device directory: %+v", err)
		}
		if tt.certFile != nil {
			if err := ioutil.WriteFile(path.Join(tmpDir, "cert.pem"), tt.certFile, 0644); err != nil {
				t.Fatalf("Failed to create fake vendor file: %+v", err)
			}
		}
		if tt.keyFile != nil {
			if err := ioutil.WriteFile(path.Join(tmpDir, "key.pem"), tt.keyFile, 0644); err != nil {
				t.Fatalf("Failed to create fake vendor file: %+v", err)
			}
		}

		s := &sds{
			keyDir:        tmpDir,
			connectionNum: tt.connectionNum,
		}
		req := &xdsapi.DiscoveryRequest{
			Node: &core.Node{
				Id: "testnode",
			},
		}
		_, err := s.FetchSecrets(nil, req)
		if tt.expectedErr && err == nil {
			t.Error("Expected error hasn't been triggered")
		}
		if !tt.expectedErr && err != nil {
			t.Errorf("Unexpected error: %+v", err)
		}

		err = os.RemoveAll(tmpDir)
		if err != nil {
			t.Fatalf("Failed to remove fake device directory: %+v", err)
		}
	}
}

type fakeStreamServer struct {
	discReq        *xdsapi.DiscoveryRequest
	recvErrs       []error
	recvCounter    int
	sendCounter    int
	sendErr        error
	keyDir         string
	updateCertFile bool
}

func (f *fakeStreamServer) Send(*xdsapi.DiscoveryResponse) error {
	f.sendCounter++
	return f.sendErr
}

func (f *fakeStreamServer) Recv() (*xdsapi.DiscoveryRequest, error) {
	if f.updateCertFile && f.recvCounter == 1 {
		// When f.recvCounter == 1 t's guarantied that the file watcher is up and running
		if err := ioutil.WriteFile(path.Join(f.keyDir, "cert.pem"), []byte("new content"), 0644); err != nil {
			return nil, errors.Wrap(err, "failed to update cert.pem")
		}
		time.Sleep(1 * time.Second)
	}

	err := f.recvErrs[f.recvCounter]
	f.recvCounter++
	return f.discReq, err
}

func (f *fakeStreamServer) SetHeader(md metadata.MD) error {
	return nil
}

func (f *fakeStreamServer) SendHeader(md metadata.MD) error {
	return nil
}

func (f *fakeStreamServer) SetTrailer(md metadata.MD) {
}

func (f *fakeStreamServer) Context() context.Context {
	return nil
}

func (f *fakeStreamServer) SendMsg(m interface{}) error {
	return nil
}

func (f *fakeStreamServer) RecvMsg(m interface{}) error {
	return nil
}

func TestStreamSecret(t *testing.T) {
	tmpDir := fmt.Sprintf("/tmp/sds-teststream-%d/", time.Now().Unix())
	tcases := []struct {
		name           string
		certFile       []byte
		keyFile        []byte
		lastNonce      string
		connectionNum  int
		discReq        *xdsapi.DiscoveryRequest
		updateCertFile bool
		recvErrs       []error
		sendErr        error
		expectedErr    bool
		expectedSends  int
	}{
		{
			name:        "Unknown connection problem",
			recvErrs:    []error{errors.New("Oops, unknown connection problem")},
			expectedErr: true,
		},
		{
			name:        "Cancel request right away",
			certFile:    []byte("fake cert"),
			keyFile:     []byte("fake key"),
			recvErrs:    []error{status.Error(codes.Canceled, "Cancel stream")},
			expectedErr: true,
		},
		{
			name:          "Reached max connections",
			certFile:      []byte("fake cert"),
			keyFile:       []byte("fake key"),
			connectionNum: maxConnections,
			expectedErr:   true,
		},
		{
			name:     "No key found",
			certFile: []byte("fake cert"),
			discReq: &xdsapi.DiscoveryRequest{
				Node: &core.Node{
					Id: "testnode",
				},
			},
			recvErrs:    []error{nil, status.Error(codes.Canceled, "Cancel stream")},
			expectedErr: true,
		},
		{
			name:        "No node ID",
			certFile:    []byte("fake cert"),
			discReq:     &xdsapi.DiscoveryRequest{},
			recvErrs:    []error{nil, status.Error(codes.Canceled, "Cancel stream")},
			expectedErr: true,
		},
		{
			name:     "Send response",
			certFile: []byte("fake cert"),
			keyFile:  []byte("fake key"),
			discReq: &xdsapi.DiscoveryRequest{
				Node: &core.Node{
					Id: "testnode",
				},
			},
			recvErrs:      []error{nil, status.Error(codes.Canceled, "Cancel stream")},
			expectedSends: 1,
			expectedErr:   true,
		},
		{
			name:     "Send response and notify about watcher event",
			certFile: []byte("fake cert"),
			keyFile:  []byte("fake key"),
			discReq: &xdsapi.DiscoveryRequest{
				Node: &core.Node{
					Id: "testnode",
				},
			},
			recvErrs:       []error{nil, status.Error(codes.Canceled, "Cancel stream")},
			updateCertFile: true,
			expectedSends:  2,
			expectedErr:    true,
		},
		{
			name:     "Send returns error",
			certFile: []byte("fake cert"),
			keyFile:  []byte("fake key"),
			discReq: &xdsapi.DiscoveryRequest{
				Node: &core.Node{
					Id: "testnode",
				},
			},
			recvErrs:      []error{nil, status.Error(codes.Canceled, "Cancel stream")},
			sendErr:       errors.New("Oops, Send error"),
			expectedSends: 1,
			expectedErr:   true,
		},
		{
			name:     "No Send for the same nonce",
			certFile: []byte("fake cert"),
			discReq: &xdsapi.DiscoveryRequest{
				ResponseNonce: "some nonce",
			},
			lastNonce:   "some nonce",
			recvErrs:    []error{nil, status.Error(codes.Canceled, "Cancel stream")},
			expectedErr: true,
		},
	}
	for _, tt := range tcases {
		fmt.Printf("Running the case \"%s\"\n", tt.name)
		if err := os.MkdirAll(tmpDir, 0755); err != nil {
			t.Fatalf("Failed to create fake device directory: %+v", err)
		}
		if tt.certFile != nil {
			if err := ioutil.WriteFile(path.Join(tmpDir, "cert.pem"), tt.certFile, 0644); err != nil {
				t.Fatalf("Failed to create fake vendor file: %+v", err)
			}
		}
		if tt.keyFile != nil {
			if err := ioutil.WriteFile(path.Join(tmpDir, "key.pem"), tt.keyFile, 0644); err != nil {
				t.Fatalf("Failed to create fake vendor file: %+v", err)
			}
		}

		s := &sds{
			lastNonce:     tt.lastNonce,
			keyDir:        tmpDir,
			connectionNum: tt.connectionNum,
		}

		streamServer := &fakeStreamServer{
			recvErrs:       tt.recvErrs,
			sendErr:        tt.sendErr,
			discReq:        tt.discReq,
			updateCertFile: tt.updateCertFile,
			keyDir:         tmpDir,
		}
		err := s.StreamSecrets(streamServer)
		if tt.expectedErr && err == nil {
			t.Error(tt.name, " Expected error hasn't been triggered")
		}
		if !tt.expectedErr && err != nil {
			t.Errorf("%s: Unexpected error: %+v", tt.name, err)
		}
		if tt.expectedSends > streamServer.sendCounter {
			t.Errorf("%s: Expected %d at least send calls, but did %d", tt.name, tt.expectedSends, streamServer.sendCounter)
		}

		err = os.RemoveAll(tmpDir)
		if err != nil {
			t.Fatalf("Failed to remove fake device directory: %+v", err)
		}
	}
}

func TestSetupAndServe(t *testing.T) {
	udsPath := "/tmp/sds-testing.sock"
	os.Remove(udsPath)

	options := &Options{
		UDSPath: udsPath,
	}
	srv := &server{
		sds: &sds{},
	}

	go srv.setupAndServe(options)

	// Wait till the grpcServer is ready to serve
	for {
		if _, err := os.Stat(udsPath); err == nil {
			break
		}
		time.Sleep(1 * time.Second)
	}

	srv.grpcServer.Stop()
}
