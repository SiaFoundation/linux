package main

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"log"
	"mime"
	"net"
	"net/http"
	"os"
	"os/signal"
	"time"

	"go.sia.tech/linux"
)

func runServer(ctx context.Context) error {
	l, err := net.Listen("tcp", ":8080")
	if err != nil {
		return fmt.Errorf("failed to start listener: %w", err)
	}
	defer l.Close()

	s := &http.Server{
		Handler: http.FileServer(http.FS(linux.Packages)),
	}
	defer s.Close()
	go func() {
		if err := s.Serve(l); err != nil && !errors.Is(err, http.ErrServerClosed) {
			panic(err)
		}
	}()

	<-ctx.Done()
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), time.Minute)
	defer shutdownCancel()
	if err := s.Shutdown(shutdownCtx); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("failed to shutdown server: %w", err)
	}
	return nil
}

func main() {
	// the host mime table decides the type of .sh otherwise, and a download
	// prompt defeats reading the install script before running it.
	if err := mime.AddExtensionType(".sh", "text/plain; charset=utf-8"); err != nil {
		log.Println("failed to register mime type:", err)
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, os.Kill)
	defer cancel()

	if err := runServer(ctx); err != nil {
		log.Println("error running server:", err)
		os.Exit(1)
	}
}
