#!/bin/sh
go mod tidy
go get github.com/cbpowell/coredns-consul
go mod tidy
go generate
GOOS={{ coredns_goos }} GOARCH={{ coredns_goarch }} go build
