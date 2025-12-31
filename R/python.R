# R/python.R
# Conda-first environment provisioning for Mixture-Models compatibility:
# - Python 3.10
# - NumPy 1.23.5 (NumPy < 1.24)
# - PyPI package: Mixture-Models==0.0.8 (imports as Mixture_Models on PyPI)

#' Get default environment name
#' @keywords internal
mm_envname <- function() {
  # Default to a dedicated env name that encodes the Python requirement
  Sys.getenv("MIXTUREMODELSR_ENVNAME", unset = "mixturemodelsr-py310")
}

#' Check if conda is available (safely)
#' @keywords internal
mm_has_conda <- function() {
  ok <- tryCatch({
    bin <- reticulate::conda_binary()
    is.character(bin) && nzchar(bin)
  }, error = function(e) FALSE)
  ok
}

#' Use configured Python environment (if already available)
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

  # 3) Otherwise: do nothing; mm_setup() will provision
  invisible(TRUE)
}

#' Check if Python module is available
#' @return Logical indicating if either mixture_models or Mixture_Models is importable
#' @export
mm_python_available <- function() {
  mm_use_env(required = FALSE)
  reticulate::py_module_available("mixture_models") ||
    reticulate::py_module_available("Mixture_Models")
}

#' Provision a conda env (Python 3.10 + NumPy 1.23.5) and install Mixture-Models
#' @param force Logical, remove and recreate the conda env
#' @keywords internal
mm_setup_conda <- function(force = FALSE) {
  # Ensure Miniconda exists (reticulate installs Miniforge/Miniconda)
  # if (!reticulate::miniconda_exists()) {
  #   message("Miniconda not found. Installing (one-time)...")
  #   reticulate::install_miniconda()
  # }

  mini_path <- tryCatch(reticulate::miniconda_path(), error = function(e) NA_character_)
  if (is.na(mini_path) || !nzchar(mini_path) || !dir.exists(mini_path)) {
    message("Miniconda not found. Installing (one-time)...")
    reticulate::install_miniconda()
    mini_path <- reticulate::miniconda_path()
  }
  # Make sure reticulate can find the conda binary this session
  reticulate::use_miniconda()

  envname <- mm_envname()

  # If force, remove existing env
  if (force && reticulate::condaenv_exists(envname)) {
    message("Removing existing conda environment: ", envname)
    reticulate::conda_remove(envname)
  }

  # Create env if missing
  if (!reticulate::condaenv_exists(envname)) {
    message("Creating conda environment '", envname, "' with Python 3.10 ...")
    # NOTE: conda_create() will create env and can install python=3.10
    reticulate::conda_create(envname, packages = "python=3.10")
  }

  # Activate env
  reticulate::use_condaenv(envname, required = TRUE)

  # Hard-pin numpy (required; upstream uses np.int, np.msort, etc.)
  message("Installing compatible NumPy (1.23.5) ...")
  reticulate::py_install("numpy==1.23.5", pip = TRUE)

  # Install Mixture-Models without allowing dependency upgrades (keeps NumPy pinned)
  message("Installing Mixture-Models==0.0.8 (no-deps) ...")
  reticulate::py_run_string("
import sys, subprocess
subprocess.check_call([sys.executable, '-m', 'pip', 'install',
                       '--upgrade', '--no-deps',
                       'Mixture-Models==0.0.8'])
")

  # Verify import (PyPI provides Mixture_Models; source provides mixture_models)
  ok <- tryCatch({
    reticulate::py_run_string("import Mixture_Models")
    TRUE
  }, error = function(e) {
    tryCatch({
      reticulate::py_run_string("import mixture_models")
      TRUE
    }, error = function(e2) FALSE)
  })

  if (!ok) {
    stop(
      "Conda provisioning completed but the Python module could not be imported.\n",
      "Run mm_py_info() for diagnostics.",
      call. = FALSE
    )
  }

  message("✓ Python ready: Python 3.10 + NumPy 1.23.5 + Mixture-Models 0.0.8")
  invisible(TRUE)
}

#' Ensure Python is configured for this session
#' @param force Logical, force re-provisioning if using conda env
#' @keywords internal
mm_require_python <- function(force = FALSE) {
  # 1) User override
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = TRUE)
    return(invisible(TRUE))
  }

  # 2) Existing conda env
  envname <- mm_envname()
  if (mm_has_conda() && reticulate::condaenv_exists(envname)) {
    reticulate::use_condaenv(envname, required = TRUE)
    return(invisible(TRUE))
  }

  # 3) Otherwise, require user to run setup
  if (force) {
    # mm_setup(force=TRUE) should be used interactively
    stop("Python environment not configured. Run mm_setup(force = TRUE) first.", call. = FALSE)
  } else {
    stop("Python environment not configured. Run mm_setup() first.", call. = FALSE)
  }
}

#' Setup mixturemodelsr (user-friendly wrapper)
#'
#' One-time setup for R users. Provisions a dedicated conda environment with
#' Python 3.10 + NumPy 1.23.5 and installs Mixture-Models==0.0.8.
#'
#' @param force Logical, force reinstallation by deleting and recreating the env
#' @return TRUE invisibly on success
#' @export
mm_setup <- function(force = FALSE) {
  if (!interactive()) {
    stop(
      "mm_setup() requires an interactive R session.\n",
      "In non-interactive mode, preconfigure Python by setting MIXTUREMODELSR_PYTHON.",
      call. = FALSE
    )
  }

  # Respect user override python, just validate
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = TRUE)
    if (!mm_python_available()) {
      stop(
        "MIXTUREMODELSR_PYTHON is set, but Mixture-Models is not importable in that Python.\n",
        "Install Mixture-Models==0.0.8 and NumPy<1.24 in that environment.",
        call. = FALSE
      )
    }
    message("✓ Using user-provided Python via MIXTUREMODELSR_PYTHON.")
    return(invisible(TRUE))
  }

  # If already available, done (unless forcing)
  if (!force && mm_python_available()) {
    message("✓ Mixture-Models is already installed and available.")
    return(invisible(TRUE))
  }

  message("Setting up mixturemodelsr Python dependencies (conda, Python 3.10)...")
  mm_setup_conda(force = force)

  invisible(TRUE)
}

#' Import Python module (supports both upstream names)
#' @keywords internal
mm_import <- function() {
  mm_require_python(force = FALSE)

  if (reticulate::py_module_available("mixture_models")) {
    return(reticulate::import("mixture_models", delay_load = FALSE, convert = FALSE))
  }
  if (reticulate::py_module_available("Mixture_Models")) {
    return(reticulate::import("Mixture_Models", delay_load = FALSE, convert = FALSE))
  }

  stop(
    "Python module is not available (tried 'mixture_models' and 'Mixture_Models').\n",
    "Run mm_setup() first, or set MIXTUREMODELSR_PYTHON to a Python 3.10 env with:\n",
    "  - NumPy 1.23.5 (or < 1.24)\n",
    "  - Mixture-Models==0.0.8",
    call. = FALSE
  )
}
