# R/python.R
# Conda-first environment provisioning for Mixture-Models compatibility.
#
# Guarantees (new users):
# - Installs Miniconda (via reticulate) if missing
# - Creates dedicated conda env with Python 3.10
# - Pins NumPy to 1.23.5
# - Installs deps without upgrading NumPy
# - Installs Mixture-Models==0.0.8 with --no-deps
#
# Key improvement vs prior version:
# - After use_condaenv(), we auto-pin MIXTUREMODELSR_PYTHON to the *actual*
#   python binary reticulate bound to, and verify numpy import.
#
# Overrides supported:
# - MIXTUREMODELSR_PYTHON=/path/to/python  -> uses user-provided python (no provisioning)
# - MIXTUREMODELSR_ENVNAME=yourenvname     -> changes conda env name

# ----------------------------
# Helpers
# ----------------------------

mm_envname <- function() {
  Sys.getenv("MIXTUREMODELSR_ENVNAME", unset = "mixturemodelsr-py310")
}

mm_has_conda <- function() {
  ok <- tryCatch({
    bin <- reticulate::conda_binary()
    is.character(bin) && nzchar(bin)
  }, error = function(e) FALSE)
  ok
}

mm_miniconda_installed <- function() {
  mp <- tryCatch(reticulate::miniconda_path(), error = function(e) "")
  nzchar(mp) && dir.exists(mp)
}

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

# Run pip install in the currently active Python
# mm_pip_install <- function(packages, extra_args = character()) {
#   if (!length(packages)) return(invisible(TRUE))
#   pkgs <- paste(sprintf("%s", packages), collapse = " ")
#   args <- paste(extra_args, collapse = " ")

#   code <- sprintf(
#     "import sys, subprocess\n"
#     "cmd = [sys.executable, '-m', 'pip', 'install'] + (%s).split() + (%s).split()\n"
#     "cmd = [c for c in cmd if c]\n"
#     "print('Running:', ' '.join(cmd))\n"
#     "subprocess.check_call(cmd)\n",
#     shQuote(pkgs), shQuote(args)
#   )

#   reticulate::py_run_string(code)
#   invisible(TRUE)
# }


mm_pip_install <- function(packages, extra_args = character()) {
  if (!length(packages)) return(invisible(TRUE))

  pkgs <- paste(packages, collapse = " ")
  args <- paste(extra_args, collapse = " ")

  # Build Python code safely (R does not concatenate adjacent strings!)
  code <- sprintf(
    paste0(
      "import sys, subprocess\n",
      "cmd = [sys.executable, '-m', 'pip', 'install'] + (%s).split() + (%s).split()\n",
      "cmd = [c for c in cmd if c]\n",
      "print('Running:', ' '.join(cmd))\n",
      "subprocess.check_call(cmd)\n"
    ),
    shQuote(pkgs),
    shQuote(args)
  )

  reticulate::py_run_string(code)
  invisible(TRUE)
}



# ----------------------------
# NEW: Pin reticulate to a stable python & verify NumPy
# ----------------------------

mm_pin_python_and_verify <- function() {
  cfg <- reticulate::py_config()

  if (!is.list(cfg) || is.null(cfg$python) || !nzchar(cfg$python)) {
    stop("reticulate::py_config() did not return a valid Python binding.", call. = FALSE)
  }

  # Auto-pin the exact python binary reticulate is using
  prev <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  Sys.setenv(MIXTUREMODELSR_PYTHON = cfg$python)

  # Force numpy import now (this prevents later r_to_py() failing with requireNumPy())
  ok_numpy <- tryCatch({
    reticulate::py_run_string("import numpy as np; print('NumPy OK:', np.__version__)")
    TRUE
  }, error = function(e) FALSE)

  if (!ok_numpy) {
    # Helpful diagnostics
    msg <- tryCatch({
      reticulate::py_run_string("import sys; print('sys.executable:', sys.executable)")
      reticulate::py_run_string("import sys; print('sys.path:', sys.path)")
      ""
    }, error = function(e) "")

    stop(
      "reticulate is bound to Python but cannot import NumPy.\n",
      "Bound Python: ", cfg$python, "\n",
      "Try: mm_setup(force=TRUE) and restart R.\n",
      call. = FALSE
    )
  }

  # If we changed the pin from a prior value, suggest a restart (safe + predictable)
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

mm_use_env <- function(required = FALSE) {
  # 1) Explicit python override wins
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = required)
    # Ensure numpy is importable in that python
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

  # 3) Otherwise: do nothing; mm_setup() will provision
  invisible(TRUE)
}

mm_python_available <- function() {
  mm_use_env(required = FALSE)
  reticulate::py_module_available("mixture_models") ||
    reticulate::py_module_available("Mixture_Models")
}

# ----------------------------
# Provisioning
# ----------------------------

mm_setup_conda <- function(force = FALSE) {
  mm_ensure_miniconda()
  envname <- mm_envname()

  if (force && reticulate::condaenv_exists(envname)) {
    message("Removing existing conda environment: ", envname)
    reticulate::conda_remove(envname)
  }

  if (!reticulate::condaenv_exists(envname)) {
    message("Creating conda environment '", envname, "' with Python 3.10 ...")
    reticulate::conda_create(envname, packages = "python=3.10")
  }

  # Activate env
  reticulate::use_condaenv(envname, required = TRUE)

  # NEW: pin python + ensure numpy import path is consistent
  mm_pin_python_and_verify()

  # Ensure pip exists
  try(reticulate::py_run_string("import pip; print('pip ok')"), silent = TRUE)

  # 1) Pin NumPy
  message("Pinning NumPy (1.23.5) ...")
  mm_pip_install("numpy==1.23.5", extra_args = c("--upgrade", "--no-user"))

  # Verify numpy now (important)
  mm_pin_python_and_verify()

  # 2) Install deps (do NOT allow numpy drift)
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

  # 3) Re-pin numpy (guard against drift)
  message("Re-pinning NumPy (1.23.5) ...")
  mm_pip_install("numpy==1.23.5", extra_args = c("--upgrade", "--no-user"))

  # 4) Install Mixture-Models without deps
  message("Installing Mixture-Models==0.0.8 (no-deps) ...")
  mm_pip_install(
    packages = "Mixture-Models==0.0.8",
    extra_args = c("--upgrade", "--no-deps", "--no-user")
  )

  # Verify import
  ok <- tryCatch({
    reticulate::py_run_string("import Mixture_Models; print('Mixture_Models import ok')")
    TRUE
  }, error = function(e) {
    tryCatch({
      reticulate::py_run_string("import mixture_models; print('mixture_models import ok')")
      TRUE
    }, error = function(e2) FALSE)
  })

  if (!ok) {
    try(reticulate::py_run_string("import numpy as np; print('NumPy version:', np.__version__)"),
        silent = TRUE)
    stop(
      "Conda provisioning completed but the Python module could not be imported.\n",
      "Try mm_setup(force=TRUE).",
      call. = FALSE
    )
  }

  # Final: ensure python pin is saved + numpy importable
  mm_pin_python_and_verify()

  message("✓ Python ready: Python 3.10 + NumPy 1.23.5 + Mixture-Models 0.0.8")
  invisible(TRUE)
}

# ----------------------------
# User-facing setup / require
# ----------------------------

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

mm_setup <- function(force = FALSE) {
  if (!interactive()) {
    stop(
      "mm_setup() requires an interactive R session.\n",
      "In non-interactive mode, preconfigure Python by setting MIXTUREMODELSR_PYTHON.",
      call. = FALSE
    )
  }

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

  if (!force && mm_python_available()) {
    message("✓ Mixture-Models is already installed and available.")
    return(invisible(TRUE))
  }

  message("Setting up mixturemodelsr Python dependencies (conda, Python 3.10)...")
  mm_setup_conda(force = force)

  invisible(TRUE)
}

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
