# R/python.R
# Conda-first environment provisioning for Mixture-Models compatibility.
#
# Guarantees (new users):
# - Installs Miniconda/Miniforge (via reticulate) if missing
# - Creates dedicated conda env with Python 3.10
# - Pins NumPy to 1.23.5
# - Installs deps without upgrading NumPy
# - Installs Mixture-Models==0.0.8 with --no-deps
#
# Key design rule (critical for reliability):
# - DO NOT initialize reticulate's embedded Python during provisioning.
#   Provision with conda/conda-run first, then bind reticulate to the env,
#   then verify imports. If Python was already initialized, ask for restart.
#
# Overrides supported:
# - MIXTUREMODELSR_PYTHON=/path/to/python  -> uses user-provided python (no provisioning)
# - MIXTUREMODELSR_ENVNAME=yourenvname     -> changes conda env name

# ----------------------------
# Helpers
# ----------------------------

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

  mp <- reticulate::miniconda_path()
  Sys.setenv(RETICULATE_MINICONDA_PATH = mp)

  conda_guess <- file.path(mp, "bin", "conda")
  if (!file.exists(conda_guess)) {
    warning("Miniconda path set but conda binary not found at expected location: ", conda_guess)
  }

  invisible(TRUE)
}

#' Is reticulate Python already initialized in this R session?
#' @keywords internal
mm_py_initialized <- function() {
  isTRUE(reticulate::py_available(initialize = FALSE))
}

#' Get conda binary path (robust)
#' @keywords internal
mm_conda_bin <- function() {
  mm_ensure_miniconda()

  bin <- tryCatch(reticulate::conda_binary(), error = function(e) "")
  if (!nzchar(bin)) {
    bin <- file.path(reticulate::miniconda_path(), "bin", "conda")
  }
  if (!file.exists(bin)) {
    stop("conda binary not found. Tried: ", bin, call. = FALSE)
  }
  bin
}

#' Run a conda command (returns output invisibly)
#' @keywords internal
mm_conda_run <- function(args) {
  conda <- mm_conda_bin()
  out <- tryCatch(
    system2(conda, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) {
      stop("Failed running conda command: conda ", paste(args, collapse = " "), call. = FALSE)
    }
  )
  invisible(out)
}

# ----------------------------
# Pin reticulate to a stable python & verify NumPy (ONLY after python is initialized)
# ----------------------------

#' Pin MIXTUREMODELSR_PYTHON to reticulate's current python and verify numpy import.
#' IMPORTANT: This function does NOT initialize Python. It only runs after Python is already initialized.
#' @keywords internal
mm_pin_python_and_verify <- function() {
  if (!mm_py_initialized()) {
    return(invisible(FALSE))
  }

  cfg <- reticulate::py_config()
  if (!is.list(cfg) || is.null(cfg$python) || !nzchar(cfg$python)) {
    stop("reticulate::py_config() did not return a valid Python binding.", call. = FALSE)
  }

  prev <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  Sys.setenv(MIXTUREMODELSR_PYTHON = cfg$python)

  ok_numpy <- tryCatch({
    reticulate::py_run_string("import numpy as np; print('NumPy OK:', np.__version__)")
    TRUE
  }, error = function(e) FALSE)

  if (!ok_numpy) {
    try(reticulate::py_run_string("import sys; print('sys.executable:', sys.executable)"), silent = TRUE)
    try(reticulate::py_run_string("import sys; print('sys.path:', sys.path)"), silent = TRUE)
    stop(
      "reticulate is bound to Python but cannot import NumPy.\n",
      "Bound Python: ", cfg$python, "\n",
      "Restart R and run mm_setup(force = TRUE) again.",
      call. = FALSE
    )
  }

  if (nzchar(prev) && !identical(prev, cfg$python)) {
    message(
      "Note: MIXTUREMODELSR_PYTHON was updated to:\n  ", cfg$python, "\n",
      "A restart of R is recommended for a clean, stable binding."
    )
  }

  invisible(TRUE)
}

# ----------------------------
# Env selection
# ----------------------------

#' Use configured Python environment (if already available)
#' @param required Logical, whether to require Python availability
#' @keywords internal
mm_use_env <- function(required = FALSE) {
  # 1) Explicit python override wins
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = required)
    mm_pin_python_and_verify()
    return(invisible(TRUE))
  }

  # 2) If conda exists and env exists, use it
  envname <- mm_envname()
  if (mm_has_conda() && reticulate::condaenv_exists(envname)) {
    reticulate::use_condaenv(envname, required = required)
    mm_pin_python_and_verify()
    return(invisible(TRUE))
  }

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

# ----------------------------
# Provisioning
# ----------------------------

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

  # IMPORTANT: Install packages WITHOUT initializing reticulate's embedded Python
  message("Installing NumPy (1.23.5) via conda ...")
  mm_conda_run(c("install", "--yes", "-n", envname, "-c", "conda-forge", "numpy=1.23.5"))

  message("Installing Python dependencies via pip (inside env) ...")
  mm_conda_run(c(
    "run", "-n", envname, "python", "-m", "pip", "install",
    "--upgrade", "--no-user",
    "matplotlib<3.9",
    "scipy<1.12",
    "scikit-learn<1.4",
    "autograd==1.3",
    "future>=0.18.2"
  ))

  message("Re-pinning NumPy (1.23.5) via conda ...")
  mm_conda_run(c("install", "--yes", "-n", envname, "-c", "conda-forge", "numpy=1.23.5"))

  message("Installing Mixture-Models==0.0.8 (no-deps) ...")
  mm_conda_run(c(
    "run", "-n", envname, "python", "-m", "pip", "install",
    "--upgrade", "--no-deps", "--no-user",
    "Mixture-Models==0.0.8"
  ))

  # If Python already initialized in this R session, we can't bind to env now.
  if (mm_py_initialized()) {
    message(
      "✓ Environment provisioned.\n",
      "Python was already initialized in this R session, so reticulate cannot switch.\n",
      "Please restart R, then run:\n",
      "  library(mixturemodelsr)\n",
      "  mm_setup()  # or mm_py_info()\n"
    )
    return(invisible(TRUE))
  }

  # Bind reticulate to env and verify imports
  reticulate::use_condaenv(envname, required = TRUE)

  # Verify numpy + Mixture-Models
  reticulate::py_run_string("import numpy as np; print('NumPy OK:', np.__version__)")

  ok <- tryCatch({
    reticulate::py_run_string("import Mixture_Models; print('Mixture_Models OK')")
    TRUE
  }, error = function(e) {
    tryCatch({
      reticulate::py_run_string("import mixture_models; print('mixture_models OK')")
      TRUE
    }, error = function(e2) FALSE)
  })

  if (!ok) {
    stop("Mixture-Models installed but not importable after setup.", call. = FALSE)
  }

  # Pin python path for future sessions (prevents drift)
  Sys.setenv(MIXTUREMODELSR_PYTHON = reticulate::py_config()$python)

  message("✓ Python ready: Python 3.10 + NumPy 1.23.5 + Mixture-Models 0.0.8")
  invisible(TRUE)
}

# ----------------------------
# User-facing setup / require
# ----------------------------

#' Ensure Python is configured for this session
#' @param force Logical, force re-provisioning if using conda env
#' @keywords internal
mm_require_python <- function(force = FALSE) {
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = TRUE)
    mm_pin_python_and_verify()
    return(invisible(TRUE))
  }

  envname <- mm_envname()
  if (mm_has_conda() && reticulate::condaenv_exists(envname)) {
    reticulate::use_condaenv(envname, required = TRUE)
    mm_pin_python_and_verify()
    return(invisible(TRUE))
  }

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
    mm_pin_python_and_verify()
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
