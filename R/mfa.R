#' Fit a Mixture of Factor Analyzers (MFA)
#'
#' Fits a mixture of factor analyzers model to data using gradient-based optimization.
#'
#' @param x Numeric matrix or data.frame (rows = observations, columns = features)
#' @param k Number of mixture components
#' @param q Number of latent factors (NULL for automatic selection)
#' @param optimizer Optimizer name: "Newton-CG" (default), "grad_descent", 
#'   "rms_prop", or "adam"
#' @param scale Initialization scale parameter (default 0.5)
#' @param ... Additional arguments passed to Python init_params() or fit() methods
#'
#' @return An mm_fit object
#' @export
#'
#' @examples
#' \dontrun{
#' # Fit MFA with 3 components and 2 latent factors
#' fit <- mm_mfa_fit(iris[, 1:4], k = 3, q = 2)
#' mm_bic(fit)
#' 
#' # Get cluster labels
#' labels <- mm_predict(fit)
#' }
mm_mfa_fit <- function(x, k, q = NULL, optimizer = "Newton-CG", scale = 0.5, ...) {
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
  model <- mm$MFA(py_x)
  
  # Initialize parameters
  init_args <- list(
    num_components = as.integer(k),
    scale = as.numeric(scale)
  )
  
  # Add q if provided
  if (!is.null(q)) {
    if (q < 1 || q >= ncol(x)) {
      stop("q must be >= 1 and < ncol(x)", call. = FALSE)
    }
    init_args$q = as.integer(q)
  }
  
  init_params <- do.call(model$init_params, init_args)
  
  # Fit model
  params_store <- model$fit(init_params, optimizer)
  
  # Get final parameters
  final_params <- params_store[[length(params_store)]]
  
  # Create fit object
  mm_new_fit(
    py_model = model,
    params_store = params_store,
    final_params = final_params,
    model_name = "MFA",
    k = k,
    call = call,
    n = nrow(x),
    d = ncol(x),
    optimizer = optimizer
  )
}
