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
#' @keywords internal
mm_require_python <- function() {
  # If user has set MIXTUREMODELSR_PYTHON, honor it
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = TRUE)
    return(invisible(TRUE))
  }

  # If conda env exists, prefer it (for users who already set it up)
  envname <- mm_envname()
  if (mm_has_conda() && reticulate::condaenv_exists(envname)) {
    reticulate::use_condaenv(envname, required = TRUE)
    return(invisible(TRUE))
  }

  # Otherwise, provision with py_require() (no conda needed - modern reticulate approach)
  message("Provisioning Python environment with py_require()...")
  reticulate::py_require(c(
    "Mixture-Models==0.0.8",
    "autograd",
    "numpy",
    "scipy",
    "scikit-learn",
    "matplotlib",
    "future"
  ))
  
  # Force resolution now so errors happen here, not later
  reticulate::py_config()
  invisible(TRUE)
}

#' Setup mixturemodelsr (user-friendly wrapper)
#'
#' Convenience function that checks if Python dependencies are installed and
#' installs them if needed. This is the recommended way for users to set up
#' the package. Uses reticulate's py_require() for automatic Python provisioning.
#'
#' @param force Logical, force reinstallation even if already installed
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

  # This will either use MIXTUREMODELSR_PYTHON, use an existing conda env,
  # or provision an environment via py_require() (modern reticulate approach)
  mm_require_python()

  if (!mm_python_available()) {
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
  mm_require_python()

  if (!reticulate::py_module_available("mixture_models")) {
    stop(
      "Python module 'mixture_models' is not available.\n",
      "Please run mm_setup() to install the required Python packages.\n",
      "\nAlternatively, if you have your own Python environment:\n",
      "  1. Install: pip install Mixture-Models==0.0.8\n",
      "  2. Set: Sys.setenv(MIXTUREMODELSR_PYTHON = '/path/to/python')",
      call. = FALSE
    )
  }

  reticulate::import("mixture_models", delay_load = FALSE, convert = FALSE)
}
