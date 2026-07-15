// Package main implements a stub daemon used by the packaging tests. It
// stands in for the real Sia daemons so the test suite can exercise package
// install, upgrade, and removal without network access.
package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	fmt.Println("stub daemon started")

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	<-ch

	fmt.Println("stub daemon stopped")
}
