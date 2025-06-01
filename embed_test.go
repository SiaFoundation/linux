package linux

import (
	"bytes"
	"io"
	"os"
	"testing"
)

func TestPackagesFS(t *testing.T) {
	assertFile := func(t *testing.T, path string) {
		t.Helper()
		expected, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}

		f, err := Packages.Open(path)
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

	assertFile(t, "debian/gpg")
	assertFile(t, "ubuntu/gpg")
	assertFile(t, "debian/db/checksums.db")
	assertFile(t, "ubuntu/db/checksums.db")
}
