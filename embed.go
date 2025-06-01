package linux

import (
	"embed"
)

//go:embed debian ubuntu
var Packages embed.FS
