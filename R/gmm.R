#' Fit a Gaussian Mixture Model (GMM)
#'
#' Fits a Gaussian mixture model to data using gradient-based optimization.
#' This is a wrapper around the Python Mixture-Models GMM implementation.
#'
#' @param x Numeric matrix or data.frame (rows = observations, columns = features)
#' @param k Number of mixture components
#' @param optimizer Optimizer name: "Newton-CG" (default), "grad_descent", 
#'   "rms_prop", or "adam"
#' @param scale Initialization scale parameter (default 0.5)
#' @param ... Additional arguments passed to Python init_params() or fit() methods
#'
#' @return An mm_fit object containing:
#'   \item{py_model}{Python model object}
#'   \item{params_store}{Full optimization path}
#'   \item{params}{Final fitted parameters}
#'   \item{model_name}{Model family name}
#'   \item{k}{Number of components}
#'   \item{call}{Original function call}
#'   \item{n}{Sample size}
#'   \item{d}{Number of dimensions}
#'   \item{optimizer}{Optimizer used}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Setup (first time only)
#' mm_setup()
#' 
#' # Fit a 3-component GMM on iris data
#' fit <- mm_gmm_fit(iris[, 1:4], k = 3)
#' print(fit)
#' 
#' # Get cluster labels
#' labels <- mm_predict(fit)
#' 
#' # Model selection
#' mm_bic(fit)
#' mm_aic(fit)
#' }
mm_gmm_fit <- function(x, k, optimizer = "Newton-CG", scale = 0.5, ...) {
  call <- match.call()
  
  # Input validation
  x <- as.matrix(x)
  if (!is.numeric(x)) {
    stop("x must be numeric", call. = FALSE)
  }
  if (nrow(x) < 2) {
    stop("x must have at least 2 rows", call. = FALSE)
  }
  if (k < 1) {
    stop("k must be >= 1", call. = FALSE)
  }
  if (k > nrow(x)) {
    warning("k is greater than number of observations. This may cause issues.")
  }
  
  # Import Python module
  mm <- mm_import()
  
  # Convert data to Python
  py_x <- reticulate::r_to_py(x)
  
  # Create model
  model <- mm$GMM(py_x)
  
  # Initialize parameters
  init_params <- model$init_params(
    num_components = as.integer(k),
    scale = as.numeric(scale)
  )
  
  # Fit model
  params_store <- model$fit(init_params, optimizer)
  
  # Get final parameters
  final_params <- params_store[[length(params_store)]]
  
  # Create fit object
  mm_new_fit(
    py_model = model,
    params_store = params_store,
    final_params = final_params,
    model_name = "GMM",
    k = k,
    call = call,
    n = nrow(x),
    d = ncol(x),
    optimizer = optimizer
  )
}

#' Fit a Constrained Gaussian Mixture Model
#'
#' Fits a GMM with a common covariance matrix across all components.
#'
#' @inheritParams mm_gmm_fit
#'
#' @return An mm_fit object
#' @export
#'
#' @examples
#' \dontrun{
#' fit <- mm_gmm_constrained_fit(iris[, 1:4], k = 3)
#' mm_bic(fit)
#' }
mm_gmm_constrained_fit <- function(x, k, optimizer = "Newton-CG", scale = 0.5, ...) {
  call <- match.call()
  
  # Input validation
  x <- as.matrix(x)
  if (!is.numeric(x)) {
    stop("x must be numeric", call. = FALSE)
  }
  if (nrow(x) < 2) {
    stop("x must have at least 2 rows", call. = FALSE)
  }
  if (k < 1) {
    stop("k must be >= 1", call. = FALSE)
  }
  
  # Import Python module
  mm <- mm_import()
  
  # Convert data to Python
  py_x <- reticulate::r_to_py(x)
  
  # Create model
  model <- mm$GMM_Constrained(py_x)
  
  # Initialize parameters
  init_params <- model$init_params(
    num_components = as.integer(k),
    scale = as.numeric(scale)
  )
  
  # Fit model
  params_store <- model$fit(init_params, optimizer)
  
  # Get final parameters
  final_params <- params_store[[length(params_store)]]
  
  # Create fit object
  mm_new_fit(
    py_model = model,
    params_store = params_store,
    final_params = final_params,
    model_name = "GMM_Constrained",
    k = k,
    call = call,
    n = nrow(x),
    d = ncol(x),
    optimizer = optimizer
  )
}
