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
#' package along with its dependencies. This function should be called once
#' before using the package for the first time.
#'
#' @param method Installation method: "auto" (default), "virtualenv", or "conda"
#' @param envname Name of the environment (default uses MIXTUREMODELSR_ENVNAME 
#'   or "mixturemodelsr")
#' @param python_version Python version to use (default "3.9")
#' @param restart_session Logical, whether to restart R session after installation
#'
#' @details
#' By default, this function creates a conda environment named "mixturemodelsr"
#' and installs Mixture-Models==0.0.8 with pinned dependencies.
#' 
#' You can customize the environment name by setting the MIXTUREMODELSR_ENVNAME
#' environment variable before calling this function.
#' 
#' Alternatively, you can install the Python package manually in your preferred
#' Python environment and set MIXTUREMODELSR_PYTHON to point to that Python
#' executable.
#'
#' @return TRUE invisibly on success
#' @export
#'
#' @examples
#' \dontrun{
#' # Standard installation
#' mm_install()
#' 
#' # Custom environment name
#' Sys.setenv(MIXTUREMODELSR_ENVNAME = "my_mm_env")
#' mm_install()
#' 
#' # Use existing Python with manual install
#' Sys.setenv(MIXTUREMODELSR_PYTHON = "/path/to/python")
#' # Then manually: pip install Mixture-Models==0.0.8
#' }
mm_install <- function(method = c("auto", "virtualenv", "conda"),
                       envname = mm_envname(),
                       python_version = "3.9",
                       restart_session = TRUE) {
  
  method <- match.arg(method)
  
  # Check for explicit Python path - if set, user manages their own env
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
  
  message("Installing Python package 'Mixture-Models' in environment: ", envname)
  
  # Determine method
  if (method == "auto") {
    method <- if (reticulate::conda_binary() != "") "conda" else "virtualenv"
  }
  
  if (method == "conda") {
    # Ensure miniconda is installed
    if (reticulate::conda_binary() == "") {
      message("Installing Miniconda...")
      reticulate::install_miniconda()
    }
    
    # Create environment if it doesn't exist
    if (!reticulate::condaenv_exists(envname)) {
      message("Creating conda environment: ", envname)
      reticulate::conda_create(envname, python_version = python_version)
    }
    
    # Install packages
    message("Installing Python packages...")
    reticulate::conda_install(
      envname = envname,
      packages = "pip",
      pip = FALSE
    )
    
    # Use the environment
    reticulate::use_condaenv(envname, required = TRUE)
    
    # Install via pip for better version control
    reticulate::py_install(
      packages = paste0("-r ", req_file),
      envname = envname,
      method = "conda",
      pip = TRUE
    )
    
  } else if (method == "virtualenv") {
    # Create virtualenv if it doesn't exist
    if (!reticulate::virtualenv_exists(envname)) {
      message("Creating virtualenv: ", envname)
      reticulate::virtualenv_create(envname, python = python_version)
    }
    
    # Install packages
    message("Installing Python packages...")
    reticulate::virtualenv_install(
      envname = envname,
      packages = paste0("-r ", req_file),
      pip = TRUE
    )
    
    reticulate::use_virtualenv(envname, required = TRUE)
  }
  
  message("\n✓ Installation complete!")
  message("\nVerifying installation...")
  
  if (mm_python_available()) {
    message("✓ Mixture-Models package is available")
    message("\nYou can now use functions like mm_gmm_fit(), mm_mfa_fit(), etc.")
    
    if (restart_session) {
      message("\nRestarting R session is recommended for changes to take effect.")
    }
  } else {
    warning("Installation completed but package verification failed. Try restarting R.")
  }
  
  invisible(TRUE)
}

#' Setup mixturemodelsr (user-friendly wrapper)
#'
#' Convenience function that checks if Python dependencies are installed and
#' installs them if needed. This is the recommended way for users to set up
#' the package.
#'
#' @param force Logical, force reinstallation even if already installed
#' @param ... Additional arguments passed to \code{\link{mm_install}}
#'
#' @return TRUE invisibly on success
#' @export
#'
#' @examples
#' \dontrun{
#' library(mixturemodelsr)
#' mm_setup()  # One-time setup
#' }
mm_setup <- function(force = FALSE, ...) {
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
  
  message("Setting up mixturemodelsr Python dependencies...")
  mm_install(...)
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
