package linux

import (
	"bytes"
	"io"
	"os"
	"testing"
)

func TestPackagesFS(t *testing.T) {
	expected, err := os.ReadFile("debian/gpg")
	if err != nil {
		t.Fatal(err)
	}

	f, err := Packages.Open("/debian/gpg")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		t.Fatal(err)
	} else if !bytes.Equal(data, expected) {
		t.Fatalf("expected %q, got %q", expected, data)
	}
}
