#' Get default environment name
#' @keywords internal
mm_envname <- function() {
  Sys.getenv("MIXTUREMODELSR_ENVNAME", unset = "mixturemodelsr")
}

#' Use configured Python environment
#' @param required Logical, whether to require Python availability
#' @keywords internal
mm_use_env <- function(required = FALSE) {
  # Check for explicit Python path override
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  if (nzchar(py_path)) {
    reticulate::use_python(py_path, required = required)
    return(invisible(TRUE))
  }
  
  # Otherwise use managed conda env
  envname <- mm_envname()
  if (reticulate::conda_binary() != "" && reticulate::condaenv_exists(envname)) {
    reticulate::use_condaenv(envname, required = required)
  }
  
  invisible(TRUE)
}

#' Check if Python module is available
#' @return Logical indicating if mixture_models Python package is available
#' @export
mm_python_available <- function() {
  mm_use_env(required = FALSE)
  reticulate::py_module_available("mixture_models")
}

#' Install Python dependencies for mixturemodelsr
#'
#' Creates a dedicated conda environment and installs the Mixture-Models Python
#' package along with its dependencies. This is typically called by mm_setup().
#'
#' @param envname Name of the environment (default uses MIXTUREMODELSR_ENVNAME 
#'   or "mixturemodelsr")
#'
#' @details
#' This function assumes Miniconda is already installed and activated.
#' It creates a conda environment and installs Mixture-Models==0.0.8.
#'
#' @return TRUE invisibly on success
#' @keywords internal
mm_install <- function(envname = mm_envname()) {
  
  # Check for explicit Python path override
  if (nzchar(Sys.getenv("MIXTUREMODELSR_PYTHON", unset = ""))) {
    message("MIXTUREMODELSR_PYTHON is set. Please install Mixture-Models manually:")
    message("  pip install Mixture-Models==0.0.8")
    return(invisible(FALSE))
  }
  
  # Get requirements file
  req_file <- system.file("python/requirements.txt", package = "mixturemodelsr")
  if (!file.exists(req_file) || req_file == "") {
    stop("requirements.txt not found in package installation.", call. = FALSE)
  }
  
  # Ensure Miniconda is activated
  reticulate::use_miniconda()
  
  # Create environment if it doesn't exist
  if (!reticulate::condaenv_exists(envname)) {
    message("Creating conda environment: ", envname)
    reticulate::conda_create(envname)
  }
  
  # Activate the environment
  message("Activating conda environment: ", envname)
  reticulate::use_condaenv(envname, required = TRUE)
  
  # Install Python packages
  message("Installing Mixture-Models and dependencies...")
  reticulate::py_install(
    packages = paste0("-r ", req_file),
    pip = TRUE
  )
  
  message("\n✓ Installation complete!")
  
  if (mm_python_available()) {
    message("✓ Mixture-Models package is available")
    message("\nYou can now use functions like mm_gmm_fit(), mm_mfa_fit(), etc.")
    message("Note: Restarting R session is recommended for changes to take full effect.")
  } else {
    warning("Installation completed but package verification failed. Try restarting R.")
  }
  
  invisible(TRUE)
}

#' Setup mixturemodelsr (user-friendly wrapper)
#'
#' Convenience function that checks if Python dependencies are installed and
#' installs them if needed. This is the recommended way for users to set up
#' the package. Automatically installs Miniconda if not present.
#'
#' @param force Logical, force reinstallation even if already installed
#'
#' @return TRUE invisibly on success
#' @export
#'
#' @examples
#' \dontrun{
#' library(mixturemodelsr)
#' mm_setup()  # One-time setup, auto-installs Miniconda if needed
#' }
mm_setup <- function(force = FALSE) {
  # Step 0: Check if already set up
  if (!force && mm_python_available()) {
    message("✓ Mixture-Models Python package is already installed and available")
    message("  Use force = TRUE to reinstall")
    return(invisible(TRUE))
  }
  
  if (!interactive()) {
    stop(
      "mm_setup() requires an interactive R session.\n",
      "In non-interactive mode, ensure Python environment is pre-configured.",
      call. = FALSE
    )
  }
  
  # Step 1: Check for user-specified Python override
  if (nzchar(Sys.getenv("MIXTUREMODELSR_PYTHON", unset = ""))) {
    message("MIXTUREMODELSR_PYTHON is set.")
    message("Please ensure Mixture-Models==0.0.8 is installed in that environment:")
    message("  pip install Mixture-Models==0.0.8")
    return(invisible(FALSE))
  }
  
  message("Setting up mixturemodelsr Python dependencies...")
  
  # Step 2: Ensure Miniconda exists (auto-install for R-only users)
  if (!reticulate::miniconda_exists()) {
    message("\nMiniconda not found. Installing Miniconda (one-time setup)...")
    message("This may take a few minutes...")
    tryCatch({
      reticulate::install_miniconda()
      message("✓ Miniconda installed successfully")
    }, error = function(e) {
      stop(
        "Failed to install Miniconda automatically.\n",
        "Error: ", conditionMessage(e), "\n\n",
        "Alternative options:\n",
        "1. Install Python/Conda manually, then set MIXTUREMODELSR_PYTHON\n",
        "2. Contact package maintainer for support",
        call. = FALSE
      )
    })
  } else {
    message("✓ Miniconda found")
  }
  
  # Step 3: Explicitly activate Miniconda in this session
  message("Activating Miniconda...")
  reticulate::use_miniconda()
  
  # Step 4: Install Python packages
  mm_install()
  
  invisible(TRUE)
}

#' Import mixture_models Python module
#' @keywords internal
mm_import <- function() {
  mm_use_env(required = FALSE)
  
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
