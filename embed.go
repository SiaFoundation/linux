package linux

import (
	"embed"
)

//go:embed debian ubuntu index.html install.sh
var Packages embed.FS
