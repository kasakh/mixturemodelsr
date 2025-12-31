#' Python Configuration Diagnostics
#'
#' Prints detailed information about the Python environment configuration
#' for mixturemodelsr. Useful for troubleshooting installation issues.
#'
#' @return Invisibly returns a list with diagnostic information
#' @export
#'
#' @examples
#' \dontrun{
#' mm_py_info()
#' }
mm_py_info <- function() {
  cat("=== mixturemodelsr Python Configuration ===\n\n")
  
  # Environment variables
  cat("## Environment Variables:\n")
  py_path <- Sys.getenv("MIXTUREMODELSR_PYTHON", unset = "")
  env_name <- Sys.getenv("MIXTUREMODELSR_ENVNAME", unset = "")
  
  if (nzchar(py_path)) {
    cat("  MIXTUREMODELSR_PYTHON:", py_path, "\n")
  } else {
    cat("  MIXTUREMODELSR_PYTHON: (not set - using managed environment)\n")
  }
  
  if (nzchar(env_name)) {
    cat("  MIXTUREMODELSR_ENVNAME:", env_name, "\n")
  } else {
    cat("  MIXTUREMODELSR_ENVNAME: (not set - using default 'mixturemodelsr')\n")
  }
  cat("\n")
  
  # Selected environment
  cat("## Selected Environment:\n")
  selected_env <- mm_envname()
  cat("  Environment name:", selected_env, "\n")
  
  # Check if conda is available
  conda_bin <- tryCatch(reticulate::conda_binary(), error = function(e) "")
  if (nzchar(conda_bin)) {
    cat("  Conda binary:", conda_bin, "\n")
    if (reticulate::condaenv_exists(selected_env)) {
      cat("  Environment exists: Yes\n")
    } else {
      cat("  Environment exists: No (run mm_setup() to create)\n")
    }
  } else {
    cat("  Conda binary: Not found\n")
  }
  cat("\n")
  
  # Python configuration
  cat("## Python Configuration:\n")
  tryCatch({
    mm_use_env(required = FALSE)
    py_config <- reticulate::py_config()
    cat("  Python:", py_config$python, "\n")
    cat("  Version:", py_config$version, "\n")
    cat("  numpy:", if (reticulate::py_module_available("numpy")) "available" else "NOT FOUND", "\n")
    cat("  scipy:", if (reticulate::py_module_available("scipy")) "available" else "NOT FOUND", "\n")
    cat("  autograd:", if (reticulate::py_module_available("autograd")) "available" else "NOT FOUND", "\n")
    cat("  mixture_models:", if (reticulate::py_module_available("mixture_models")) "available" else "NOT FOUND", "\n")
  }, error = function(e) {
    cat("  Python configuration: Not available\n")
    cat("  Error:", conditionMessage(e), "\n")
  })
  cat("\n")
  
  # Package version info
  cat("## Package Version Info:\n")
  if (mm_python_available()) {
    tryCatch({
      reticulate::py_run_string("import mixture_models; print('Mixture-Models version:', mixture_models.__version__)")
    }, error = function(e) {
      cat("  Unable to retrieve version information\n")
    })
  } else {
    cat("  mixture_models package: NOT INSTALLED\n")
    cat("  Run mm_setup() to install\n")
  }
  cat("\n")
  
  # Full py_config
  cat("## Full Python Configuration:\n")
  tryCatch({
    print(reticulate::py_config())
  }, error = function(e) {
    cat("  Unable to retrieve Python configuration\n")
  })
  cat("\n")
  
  # Installation instructions
  if (!mm_python_available()) {
    cat("=== Installation Required ===\n")
    cat("The Mixture-Models Python package is not available.\n\n")
    cat("To install:\n")
    cat("  mm_setup()\n\n")
    cat("Or manually:\n")
    cat("  1. Install: pip install Mixture-Models==0.0.8\n")
    cat("  2. Set: Sys.setenv(MIXTUREMODELSR_PYTHON = '/path/to/python')\n")
  } else {
    cat("=== Status ===\n")
    cat("✓ Mixture-Models package is available and ready to use!\n")
  }
  
  # Return diagnostic info invisibly
  invisible(list(
    env_vars = list(
      python_path = py_path,
      env_name = env_name
    ),
    selected_env = selected_env,
    python_available = mm_python_available(),
    py_config = tryCatch(reticulate::py_config(), error = function(e) NULL)
  ))
}
