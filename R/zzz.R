.onLoad <- function(libname, pkgname) {
  # Don't force Python environment selection on load
  # Users must explicitly call mm_setup() or wrapper functions will error
  invisible()
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "mixturemodelsr: R interface to Mixture-Models Python package\n",
    "First time? Run mm_setup() to install Python dependencies.\n",
    "For help: ?mixturemodelsr or mm_py_info() for diagnostics."
  )
}
