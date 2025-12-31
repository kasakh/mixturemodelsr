# R/python.R
# Conda-first environment provisioning for Mixture-Models compatibility.
#
# What this guarantees for NEW users:
# - Installs Miniconda/Miniforge (via reticulate) if missing
# - Creates a dedicated conda env with Python 3.10
# - Pins NumPy to 1.23.5 (NumPy < 1.24) to keep legacy aliases (np.int, np.msort)
# - Installs required deps (matplotlib/scipy/sklearn/autograd/future) WITHOUT upgrading NumPy
# - Installs Mixture-Models==0.0.8 with --no-deps (prevents pip from drifting NumPy)
# - Verifies import (PyPI installs as Mixture_Models; source may be mixture_models)
#
# Overrides supported:
# - MIXTUREMODELSR_PYTHON=/path/to/python  -> uses user-provided python (no provisioning)
# - MIXTUREMODELSR_ENVNAME=yourenvname     -> changes conda env name

#' Get default environment name
#' @keywords internal
mm_envname <- function() {
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

#' Is Miniconda/Miniforge installed (reticulate-managed)?
#' @keywords internal
mm_miniconda_installed <- function() {
  mp <- tryCatch(reticulate::miniconda_path(), error = function(e) "")
  nzchar(mp) && dir.exists(mp)
}

#' Ensure Miniconda/Miniforge is installed and discoverable
#' @keywords internal
mm_ensure_miniconda <- function() {
  if (!mm_miniconda_installed()) {
    message("Miniconda not found. Installing (one-time)...")
    reticulate::install_miniconda()
  }

  # Help reticulate locate conda reliably across versions
  mp <- reticulate::miniconda_path()
  Sys.setenv(RETICULATE_MINICONDA_PATH = mp)

  # Sanity: ensure conda exists at expected location
  conda_guess <- file.path(mp, "bin", "conda")
  if (!file.exists(conda_guess)) {
    # Not fatal here; reticulate may still find it via PATH, but warn.
    warning("Miniconda path set but conda binary not found at expected location: ", conda_guess)
  }

  invisible(TRUE)
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

#' Run pip install in the currently active Python
#' @param packages character vector of requirement strings
#' @param extra_args character vector of extra pip args (e.g., "--no-deps")
#' @keywords internal
mm_pip_install <- function(packages, extra_args = character()) {
  if (!length(packages)) return(invisible(TRUE))
  pkgs <- paste(sprintf("\"%s\"", packages), collapse = ", ")
  args <- if (length(extra_args) > 0) paste(sprintf("\"%s\"", extra_args), collapse = ", ") else ""
  
  code <- if (nzchar(args)) {
    sprintf(
      "import sys, subprocess\ncmd = [sys.executable, '-m', 'pip', 'install'] + [%s] + [%s]\ncmd = [c for c in cmd if c]\nsubprocess.check_call(cmd)",
      pkgs, args
    )
  } else {
    sprintf(
      "import sys, subprocess\ncmd = [sys.executable, '-m', 'pip', 'install'] + [%s]\nsubprocess.check_call(cmd)",
      pkgs
    )
  }
  
  reticulate::py_run_string(code)
  invisible(TRUE)
}

#' Provision a conda env (Python 3.10 + NumPy 1.23.5) and install Mixture-Models
#' @param force Logical, remove and recreate the conda env
#' @keywords internal
mm_setup_conda <- function(force = FALSE) {
  mm_ensure_miniconda()

  envname <- mm_envname()

  # Remove env if forcing
  if (force && reticulate::condaenv_exists(envname)) {
    message("Removing existing conda environment: ", envname)
    reticulate::conda_remove(envname)
  }

  # Create env if missing (Python 3.10)
  if (!reticulate::condaenv_exists(envname)) {
    message("Creating conda environment '", envname, "' with Python 3.10 ...")
    reticulate::conda_create(envname, packages = "python=3.10")
  }

  # Activate env
  reticulate::use_condaenv(envname, required = TRUE)

  # Ensure pip exists (conda env usually has it, but be safe)
  try(reticulate::py_run_string("import pip"), silent = TRUE)

  # ---- Critical pins / installs for upstream compatibility ----

  # 1) Pin NumPy to known-good version (keeps np.int, np.msort)
  message("Pinning NumPy (1.23.5) ...")
  mm_pip_install("numpy==1.23.5", extra_args = c("--upgrade", "--no-user"))

  # 2) Install required dependencies.
  # IMPORTANT: do NOT allow these installs to upgrade numpy to 2.x.
  # We'll re-pin numpy immediately after.
  message("Installing Python dependencies ...")
  mm_pip_install(
    packages = c(
      "matplotlib<3.9",
      "scipy<1.12",
      "scikit-learn<1.4",
      "autograd==1.3",
      "future>=0.18.2"
    ),
    extra_args = c("--upgrade", "--no-user")
  )

  # 3) Re-pin NumPy again to prevent drift
  message("Re-pinning NumPy (1.23.5) ...")
  mm_pip_install("numpy==1.23.5", extra_args = c("--upgrade", "--no-user"))

  # 4) Install Mixture-Models without deps (prevents numpy upgrades)
  message("Installing Mixture-Models==0.0.8 (no-deps) ...")
  mm_pip_install(
    packages = "Mixture-Models==0.0.8",
    extra_args = c("--upgrade", "--no-deps", "--no-user")
  )

  # Verify import (PyPI provides Mixture_Models; source may provide mixture_models)
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
    # Provide a helpful hint about numpy if import fails
    try(reticulate::py_run_string("import numpy as np; print('NumPy version:', np.__version__)"), silent = TRUE)
    stop(
      "Conda provisioning completed but the Python module could not be imported.\n",
      "This usually means NumPy drifted to an incompatible version.\n",
      "Try mm_setup(force = TRUE), or run mm_py_info() for diagnostics.",
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

  # 3) Otherwise require user to run setup
  if (force) {
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
