#' Get default environment name
#' @keywords internal
mm_envname <- function() {
  Sys.getenv("MIXTUREMODELSR_ENVNAME", unset = "mixturemodelsr")
}

#' Check if conda is available (safely)
#' @keywords internal
mm_has_conda <- function() {
  # conda_binary() throws if conda is not installed, doesn't return ""
  ok <- tryCatch({
    bin <- reticulate::conda_binary()
    is.character(bin) && nzchar(bin)
  }, error = function(e) FALSE)
  ok
}

#' Use configured Python environment
#' @param required Logical, whether to require Python availability
#' @keywords internal
mm_use_env <- function(required = FALSE) {
  # 1) Explicit python override wins
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = required)
    return(invisible(TRUE))
  }

  # 2) If conda exists and env exists, use it
  envname <- mm_envname()
  if (mm_has_conda() && reticulate::condaenv_exists(envname)) {
    reticulate::use_condaenv(envname, required = required)
    return(invisible(TRUE))
  }

  # 3) Otherwise: do nothing here (mm_setup() will provision via py_require())
  invisible(TRUE)
}

#' Check if Python module is available
#' @return Logical indicating if mixture_models Python package is available
#' @export
mm_python_available <- function() {
  mm_use_env(required = FALSE)
  reticulate::py_module_available("mixture_models")
}

#' Provision Python environment with required packages
#' @param force Logical, force re-provisioning
#' @keywords internal
mm_require_python <- function(force = FALSE) {
  # If user explicitly sets a Python, honor it and do NOT provision
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = TRUE)
    return(invisible(TRUE))
  }

  # If user already has conda + env, allow it (optional)
  envname <- mm_envname()
  if (mm_has_conda() && reticulate::condaenv_exists(envname)) {
    reticulate::use_condaenv(envname, required = TRUE)
    return(invisible(TRUE))
  }

  # Managed venv via py_require (recommended)
  # Use normalized PyPI name "mixture-models" and pin compatible dependencies
  pkgs <- c(
    "git+https://github.com/kasakh/Mixture-Models@ceb192b",
    "autograd==1.6",
    "numpy==1.26",
    "scipy==1.14",
    "scikit-learn<1.4",
    "matplotlib<3.9",
    "future>=0.18.2"
  )

  # If Python has already been initialized, we can only add packages
  if (reticulate::py_available(initialize = FALSE)) {
    if (force) {
      stop(
        "Cannot force a fresh managed Python environment after Python has initialized.\n",
        "Please restart R, then run mm_setup(force = TRUE) again.",
        call. = FALSE
      )
    }
    reticulate::py_require(pkgs, action = "add")
  } else {
    # Safe to fully define the environment before initialization
    reticulate::py_require(
      pkgs,
      python_version = "==3.10.*",
      action = "set"
    )
  }

  # Force initialization now so errors occur here
  reticulate::py_config()
  invisible(TRUE)
}

#' Setup mixturemodelsr (user-friendly wrapper)
#'
#' Convenience function that checks if Python dependencies are installed and
#' installs them if needed. This is the recommended way for users to set up
#' the package. Uses reticulate's py_require() for automatic Python provisioning.
#'
#' @param force Logical, force re-provisioning (requires restart if Python already initialized)
#'
#' @return TRUE invisibly on success
#' @export
#'
#' @examples
#' \dontrun{
#' library(mixturemodelsr)
#' mm_setup()  # One-time setup, auto-provisions Python environment
#' }
mm_setup <- function(force = FALSE) {
  if (!interactive()) {
    stop(
      "mm_setup() requires an interactive R session.\n",
      "In non-interactive mode, ensure Python environment is pre-configured.",
      call. = FALSE
    )
  }

  if (!force && mm_python_available()) {
    message("✓ Mixture-Models Python package is already installed and available")
    message("  Use force = TRUE to reinstall")
    return(invisible(TRUE))
  }

  message("Setting up mixturemodelsr Python dependencies...")

  mm_require_python(force = force)

  if (!reticulate::py_module_available("mixture_models")) {
    # Distinguish "not installed" vs "installed but import error"
    err <- tryCatch({
      reticulate::py_run_string("import mixture_models")
      NULL
    }, error = function(e) reticulate::py_last_error())

    if (!is.null(err)) {
      stop(
        "Python module 'mixture_models' is still not available.\n\n",
        "Python error:\n",
        paste0(capture.output(print(err)), collapse = "\n"),
        "\n\nTry:\n",
        "1) Restart R\n",
        "2) Run mm_setup(force = TRUE)\n",
        call. = FALSE
      )
    }

    stop(
      "Setup ran but 'mixture_models' is still not available.\n",
      "Run mm_py_info() for diagnostics.",
      call. = FALSE
    )
  }

  message("✓ Setup complete. You can now fit models (e.g., mm_gmm_fit()).")
  invisible(TRUE)
}

#' Import mixture_models Python module
#' @keywords internal
mm_import <- function() {
  mm_require_python(force = FALSE)

  if (!reticulate::py_module_available("mixture_models")) {
    stop(
      "Python module 'mixture_models' is not available.\n",
      "Please run mm_setup() to install the required Python packages.\n",
      "\nAlternatively, if you have your own Python environment:\n",
      "  1. Install: pip install mixture-models==0.0.8\n",
      "  2. Set: Sys.setenv(MIXTUREMODELSR_PYTHON = '/path/to/python')",
      call. = FALSE
    )
  }

  reticulate::import("mixture_models", delay_load = FALSE, convert = FALSE)
}
