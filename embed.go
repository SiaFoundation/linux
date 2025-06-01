package linux

import (
	"embed"
	"io/fs"
	"strings"
)

//go:embed debian
var debian embed.FS

//go:embed ubuntu
var ubuntu embed.FS

// Packages is a merged filesystem that provides access to both Debian and Ubuntu package files.
// It allows for accessing files from either distribution using a unified path structure.
var Packages fs.FS = func() fs.FS {
	debian, err := fs.Sub(debian, "debian")
	if err != nil {
		panic("failed to create subdirectory for debian: " + err.Error())
	}
	ubuntu, err := fs.Sub(ubuntu, "ubuntu")
	if err != nil {
		panic("failed to create subdirectory for ubuntu: " + err.Error())
	}
	return mergeFS{
		debian: debian,
		ubuntu: ubuntu,
	}
}()

type mergeFS struct {
	debian fs.FS
	ubuntu fs.FS
}

func (m mergeFS) Open(name string) (fs.File, error) {
	if strings.HasPrefix(name, "/") {
		name = strings.TrimPrefix(name, "/")
	}
	switch {
	case strings.HasPrefix(name, "debian/"):
		return m.debian.Open(strings.TrimPrefix(name, "debian/"))
	case strings.HasPrefix(name, "ubuntu/"):
		return m.ubuntu.Open(strings.TrimPrefix(name, "ubuntu/"))
	default:
		return nil, fs.ErrNotExist
	}
}
